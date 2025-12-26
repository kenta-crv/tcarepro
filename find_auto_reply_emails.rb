require 'net/imap'
require 'mail'

# Email configuration
IMAP_HOST = 'imap.lolipop.jp'
IMAP_PORT = 993
IMAP_USERNAME = 'mail@tele-match.net'
IMAP_PASSWORD = ENV['EMAIL_PASSWORD'] || 'fssds_t84kAd4'

puts "=" * 100
puts "SEARCHING FOR AUTO-REPLY EMAILS FROM FORM SUBMISSIONS"
puts "=" * 100

# First, get the verified email from database
verified_tracking = ContactTracking.where(email_received: true).order(email_received_at: :desc).first

if verified_tracking
  puts "\n✓ Found verified email in database:"
  puts "  ContactTracking ID: #{verified_tracking.id}"
  puts "  Company: #{verified_tracking.customer&.company || 'Unknown'}"
  puts "  Email From: #{verified_tracking.email_from}"
  puts "  Email Subject: #{verified_tracking.email_subject}"
  puts "  Received At: #{verified_tracking.email_received_at}"
  puts "  Sent At: #{verified_tracking.sended_at}"
end

puts "\n" + "=" * 100
puts "SEARCHING INBOX FOR AUTO-REPLY EMAILS"
puts "=" * 100

begin
  # Connect to IMAP
  imap = Net::IMAP.new(IMAP_HOST, port: IMAP_PORT, ssl: true)
  imap.login(IMAP_USERNAME, IMAP_PASSWORD)
  puts "\n✓ Connected to IMAP server"
  
  imap.select('INBOX')
  
  # Get all sent submissions
  sent_submissions = ContactTracking.where(status: ['送信済', '送信成功'])
                                    .order(sended_at: :desc)
                                    .includes(:customer)
  
  puts "\n✓ Found #{sent_submissions.count} sent submissions in database"
  
  # Search for emails in last 3 days
  since_date = (Date.today - 3).strftime('%d-%b-%Y')
  email_ids = imap.search(['SINCE', since_date])
  puts "✓ Found #{email_ids.length} emails in last 3 days\n"
  
  puts "\n" + "=" * 100
  puts "POTENTIAL AUTO-REPLY EMAILS"
  puts "=" * 100
  
  potential_auto_replies = []
  
  email_ids.each do |email_id|
    begin
      envelope = imap.fetch(email_id, 'ENVELOPE')[0].attr['ENVELOPE']
      body = imap.fetch(email_id, 'RFC822')[0].attr['RFC822']
      mail = Mail.read_from_string(body)
      
      from = if envelope.from && envelope.from[0]
        "#{envelope.from[0].mailbox}@#{envelope.from[0].host}"
      else
        mail.from&.first || 'Unknown'
      end
      
      subject = begin
        if envelope.subject
          decoded = Mail::Encodings.value_decode(envelope.subject) rescue envelope.subject
          decoded.to_s.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace)
        else
          mail.subject || '(No Subject)'
        end
      rescue
        mail.subject || '(No Subject)'
      end
      
      date = begin
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
          Time.parse(date_obj.to_s)
        end
      rescue
        Time.now
      end
      
      body_content = begin
        if mail.body
          mail.body.decoded.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace)
        else
          ''
        end
      rescue
        ''
      end
      
      # Check if this looks like an auto-reply
      auto_reply_keywords = [
        'お問い合わせ', '問い合わせ', 'inquiry', 'contact', 'お問合せ',
        'ありがとう', 'thank you', '確認', 'confirmation', '受付', 'received',
        'お申し込み', 'application', 'ご依頼', 'request'
      ]
      
      subject_lower = subject.downcase
      body_lower = body_content.downcase
      
      has_auto_reply_keyword = auto_reply_keywords.any? { |keyword| 
        subject_lower.include?(keyword.downcase) || body_lower.include?(keyword.downcase)
      }
      
      # Check if it's from a company domain (not personal email)
      is_company_email = !from.include?('gmail.com') && 
                         !from.include?('yahoo.com') && 
                         !from.include?('hotmail.com') &&
                         !from.include?('outlook.com') &&
                         from.include?('@')
      
      # Check if it's not a newsletter/marketing email
      marketing_keywords = ['newsletter', 'ニュースレター', 'セミナー', 'seminar', 'マガジン', 'magazine', '配信', 'メルマガ']
      is_marketing = marketing_keywords.any? { |keyword| 
        subject_lower.include?(keyword.downcase) || body_lower.include?(keyword.downcase)
      }
      
      if has_auto_reply_keyword && is_company_email && !is_marketing
        # Try to match with a submission
        matched_submission = sent_submissions.find do |submission|
          # Check if email date is after submission date
          next false unless submission.sended_at
          next false if date < submission.sended_at
          next false if date > submission.sended_at + 7.days
          
          # Check company name in subject or body
          company_name = submission.customer&.company || ''
          next false if company_name.blank?
          
          normalized_company = company_name.gsub(/株式会社|有限会社|合同会社|\(株\)|\(有\)/, '').strip.downcase
          company_text = normalized_company.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace).downcase
          
          subject_lower.include?(company_text) || body_lower.include?(company_text) ||
          subject_lower.include?(company_name.downcase) || body_lower.include?(company_name.downcase)
        end
        
        match_status = if matched_submission
          if matched_submission.email_received?
            "✓ MATCHED & VERIFIED (CT ID: #{matched_submission.id})"
          else
            "⚠ MATCHED but NOT VERIFIED (CT ID: #{matched_submission.id})"
          end
        else
          "⚠ NOT MATCHED - Potential auto-reply"
        end
        
        potential_auto_replies << {
          email_id: email_id,
          from: from,
          subject: subject,
          date: date,
          match_status: match_status,
          matched_submission: matched_submission
        }
      end
      
    rescue => e
      # Skip errors
    end
  end
  
  if potential_auto_replies.any?
    potential_auto_replies.each_with_index do |email, index|
      puts "\n[#{index + 1}] Email ID: #{email[:email_id]}"
      puts "  From: #{email[:from]}"
      puts "  Subject: #{email[:subject]}"
      puts "  Date: #{email[:date].strftime('%Y-%m-%d %H:%M:%S')}"
      puts "  Status: #{email[:match_status]}"
      if email[:matched_submission]
        puts "  Company: #{email[:matched_submission].customer&.company || 'Unknown'}"
        puts "  Submission Date: #{email[:matched_submission].sended_at&.strftime('%Y-%m-%d %H:%M:%S')}"
      end
      puts "  " + "-" * 98
    end
  else
    puts "\n⚠ No potential auto-reply emails found in last 3 days"
    puts "  (This could mean:)"
    puts "  - Companies haven't sent auto-replies yet"
    puts "  - Emails are older than 3 days"
    puts "  - Emails don't contain typical auto-reply keywords"
  end
  
  imap.disconnect
  puts "\n✓ Disconnected from IMAP server"
  
rescue => e
  puts "\n✗ Error: #{e.message}"
  puts e.backtrace.first(10)
end

