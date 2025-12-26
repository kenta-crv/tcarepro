require 'net/imap'
require 'mail'

class EmailVerificationWorker
  include Sidekiq::Worker
  sidekiq_options retry: 3, queue: 'default', backtrace: true

  # Email account configuration
  IMAP_HOST = 'imap.lolipop.jp'
  IMAP_PORT = 993
  IMAP_USERNAME = 'mail@tele-match.net'
  IMAP_PASSWORD = ENV['EMAIL_PASSWORD'] || 'fssds_t84kAd4' # Fallback to provided password
  
  # How far back to check for emails (in hours)
  CHECK_HOURS_BACK = 24

  def perform
    Rails.logger.info "EmailVerificationWorker: Starting email verification check"
    
    begin
      # Connect to IMAP server
      imap = connect_to_imap
      return unless imap

      # Select inbox
      imap.select('INBOX')
      
      # Get recent emails (last 24 hours)
      since_time = (Time.now - CHECK_HOURS_BACK.hours)
      search_criteria = ['SINCE', since_time.strftime('%d-%b-%Y')]
      
      Rails.logger.info "EmailVerificationWorker: Searching for emails since #{since_time}"
      email_ids = imap.search(search_criteria)
      
      Rails.logger.info "EmailVerificationWorker: Found #{email_ids.length} emails to check"
      
      # Process each email
      email_ids.each do |email_id|
        process_email(imap, email_id)
      end
      
      imap.disconnect
      Rails.logger.info "EmailVerificationWorker: Email verification check completed"
      
    rescue => e
      Rails.logger.error "EmailVerificationWorker: Error during email verification: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    end
  end

  private

  def connect_to_imap
    imap = Net::IMAP.new(IMAP_HOST, port: IMAP_PORT, ssl: true)
    imap.login(IMAP_USERNAME, IMAP_PASSWORD)
    Rails.logger.info "EmailVerificationWorker: Connected to IMAP server"
    imap
  rescue => e
    Rails.logger.error "EmailVerificationWorker: Failed to connect to IMAP: #{e.message}"
    nil
  end

  def process_email(imap, email_id)
    # Fetch email envelope and body
    envelope = imap.fetch(email_id, 'ENVELOPE')[0].attr['ENVELOPE']
    body = imap.fetch(email_id, 'RFC822')[0].attr['RFC822']
    
    return unless envelope && body
    
    # Parse email
    mail = Mail.read_from_string(body)
    
    email_subject = envelope.subject || mail.subject || ''
    email_from = if envelope.from && envelope.from[0]
      "#{envelope.from[0].mailbox}@#{envelope.from[0].host}"
    elsif mail.from && mail.from.first
      mail.from.first.to_s
    else
      'unknown@unknown.com'
    end
    # Parse email date - ensure it's a Time object
    email_date = begin
      date_obj = envelope.date || mail.date
      if date_obj.nil?
        Time.now
      elsif date_obj.is_a?(Time)
        date_obj
      elsif date_obj.is_a?(DateTime)
        date_obj.to_time
      elsif date_obj.is_a?(Date)
        date_obj.to_time
      else
        # Try parsing as string
        parsed = Time.parse(date_obj.to_s)
        parsed
      end
    rescue => e
      Rails.logger.warn "EmailVerificationWorker: Could not parse email date: #{date_obj.inspect}, using current time. Error: #{e.message}"
      Time.now
    end
    
    Rails.logger.info "EmailVerificationWorker: Processing email - From: #{email_from}, Subject: #{email_subject}, Date: #{email_date}"
    
    # Try to match email to a submission
    matched_tracking = match_email_to_submission(email_from, email_subject, email_date, mail)
    
    if matched_tracking
      Rails.logger.info "EmailVerificationWorker: Matched email to ContactTracking ID #{matched_tracking.id}"
      update_tracking_with_email(matched_tracking, email_subject, email_from, email_date)
    else
      Rails.logger.debug "EmailVerificationWorker: Could not match email to any submission"
    end
    
  rescue => e
    Rails.logger.error "EmailVerificationWorker: Error processing email #{email_id}: #{e.message}"
  end

  def match_email_to_submission(email_from, email_subject, email_date, mail)
    # Ensure email_date is a Time object (should already be from process_email, but double-check)
    email_date = begin
      if email_date.is_a?(Time)
        email_date
      elsif email_date.is_a?(DateTime)
        email_date.to_time
      elsif email_date.is_a?(Date)
        email_date.to_time
      else
        Time.parse(email_date.to_s)
      end
    rescue => e
      Rails.logger.warn "EmailVerificationWorker: Could not parse email_date in match_email_to_submission: #{email_date.inspect}, using current time. Error: #{e.message}"
      Time.now
    end
    
    # Find submissions that were sent recently (within 24 hours before email date)
    # and haven't been matched yet
    time_window_start = email_date - 24.hours
    time_window_end = email_date + 1.hour # Allow 1 hour buffer after email
    
    # Get candidate submissions
    candidates = ContactTracking.where(
      status: ['送信済', '送信成功'],
      email_received: false
    ).where(
      'sended_at >= ? AND sended_at <= ?',
      time_window_start,
      time_window_end
    )
    
    # Try to match by company name in subject/body
    candidates.each do |tracking|
      if matches_submission?(tracking, email_from, email_subject, mail)
        return tracking
      end
    end
    
    nil
  end

  def matches_submission?(tracking, email_from, email_subject, mail)
    customer = tracking.customer
    return false unless customer
    
    company_name = customer.company || ''
    return false if company_name.blank?
    
    begin
      # Normalize company name for matching (remove common suffixes and variations)
      normalized_company = company_name.gsub(/株式会社|有限会社|合同会社|合資会社|一般社団法人|公益社団法人|医療法人|学校法人|社会福祉法人|特定非営利活動法人|NPO法人|\(株\)|\(有\)|\(合\)|\(医\)|\(学\)|\(社\)|\(特\)|\(NPO\)/, '').strip
      
      # Also try company kana name
      company_kana = customer.company_kana || ''
      normalized_kana = company_kana.gsub(/カブシキガイシャ|ユウゲンガイシャ|ゴウドウガイシャ|ゴウシガイシャ/, '').strip
      
      # Decode email subject if it's encoded (MIME encoded)
      decoded_subject = begin
        if email_subject.to_s.include?('=?')
          Mail::Encodings.value_decode(email_subject)
        else
          email_subject.to_s
        end
      rescue
        email_subject.to_s
      end
      
      # Get email body with proper encoding
      body_content = begin
        if mail.body
          mail.body.decoded
        else
          ''
        end
      rescue
        ''
      end
      
      # Normalize all text to UTF-8 and lowercase for comparison
      subject_text = decoded_subject.to_s.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace).downcase
      body_text = body_content.to_s.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace).downcase
      company_text = normalized_company.to_s.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace).downcase
      kana_text = normalized_kana.to_s.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace).downcase
      
      # Strategy 1: Match if company name (normalized) is in subject or body
      if company_text.present? && (subject_text.include?(company_text) || body_text.include?(company_text))
        Rails.logger.info "EmailVerificationWorker: Matched by company name: #{company_name}"
        return true
      end
      
      # Strategy 2: Match if company kana name is in subject or body
      if kana_text.present? && (subject_text.include?(kana_text) || body_text.include?(kana_text))
        Rails.logger.info "EmailVerificationWorker: Matched by company kana name: #{company_kana}"
        return true
      end
      
      # Strategy 3: Match if full company name (with suffixes) is in subject or body
      full_company_text = company_name.to_s.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace).downcase
      if subject_text.include?(full_company_text) || body_text.include?(full_company_text)
        Rails.logger.info "EmailVerificationWorker: Matched by full company name: #{company_name}"
        return true
      end
      
      # Strategy 4: Match by partial company name (at least 3 characters)
      if company_text.length >= 3
        # Try matching first 3+ characters of company name
        company_prefix = company_text[0..2]
        if subject_text.include?(company_prefix) || body_text.include?(company_prefix)
          # Additional check: make sure it's not too generic
          if company_text.length >= 5 || company_prefix.length >= 4
            Rails.logger.info "EmailVerificationWorker: Matched by company name prefix: #{company_name}"
            return true
          end
        end
      end
      
    rescue => e
      Rails.logger.warn "EmailVerificationWorker: Error in matching logic for company #{company_name}: #{e.message}"
      # Continue to try domain matching
    end
    
    # Strategy 5: Match if the email is from the company's domain
    if customer.contact_url.present? || customer.website_url.present?
      begin
        url_to_check = customer.contact_url.presence || customer.website_url
        company_domain = URI.parse(url_to_check).host rescue nil
        
        if company_domain
          # Remove www. prefix for comparison
          clean_domain = company_domain.gsub(/^www\./, '')
          email_domain = email_from.split('@').last.downcase if email_from.include?('@')
          
          if email_domain
            # Direct domain match
            if email_domain == clean_domain || email_domain.include?(clean_domain) || clean_domain.include?(email_domain)
              Rails.logger.info "EmailVerificationWorker: Matched by domain: #{email_domain} -> #{clean_domain}"
              return true
            end
            
            # Match by domain without TLD (e.g., "example" from "example.co.jp")
            domain_parts = clean_domain.split('.')
            email_parts = email_domain.split('.')
            
            if domain_parts.any? && email_parts.any?
              # Check if main domain part matches (first part before first dot)
              if domain_parts.first == email_parts.first && domain_parts.first.length >= 3
                Rails.logger.info "EmailVerificationWorker: Matched by domain root: #{domain_parts.first}"
                return true
              end
            end
          end
        end
      rescue => e
        Rails.logger.warn "EmailVerificationWorker: Error in domain matching: #{e.message}"
      end
    end
    
    false
  end

  def update_tracking_with_email(tracking, email_subject, email_from, email_date)
    tracking.update!(
      email_received: true,
      email_received_at: email_date,
      email_subject: email_subject,
      email_from: email_from,
      email_matched_at: Time.current
    )
    
    Rails.logger.info "EmailVerificationWorker: Updated ContactTracking ID #{tracking.id} with email receipt"
  end
end

