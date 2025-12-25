require 'net/imap'
require 'mail'

# Email configuration
IMAP_HOST = 'imap.lolipop.jp'
IMAP_PORT = 993
IMAP_USERNAME = 'mail@tele-match.net'
IMAP_PASSWORD = ENV['EMAIL_PASSWORD'] || 'fssds_t84kAd4'

puts "=" * 100
puts "EMAIL INBOX CHECKER AND VERIFIER"
puts "=" * 100
puts "\nConnecting to IMAP server: #{IMAP_HOST}:#{IMAP_PORT}..."

begin
  # Connect to IMAP
  imap = Net::IMAP.new(IMAP_HOST, port: IMAP_PORT, ssl: true)
  imap.login(IMAP_USERNAME, IMAP_PASSWORD)
  puts "✓ Successfully connected to IMAP server!"
  
  # Select inbox
  imap.select('INBOX')
  
  # Get email count
  total_emails = imap.search(['ALL']).length
  puts "✓ Total emails in inbox: #{total_emails}"
  
  # Get emails from last 7 days
  since_date = (Date.today - 7).strftime('%d-%b-%Y')
  recent_email_ids = imap.search(['SINCE', since_date])
  puts "✓ Emails in last 7 days: #{recent_email_ids.length}\n"
  
  puts "\n" + "=" * 100
  puts "RECENT EMAILS (Last 20)"
  puts "=" * 100
  
  # Process last 20 emails
  emails_to_check = recent_email_ids.last(20).reverse
  
  emails_to_check.each_with_index do |email_id, index|
    begin
      # Fetch email data
      envelope = imap.fetch(email_id, 'ENVELOPE')[0].attr['ENVELOPE']
      body = imap.fetch(email_id, 'RFC822')[0].attr['RFC822']
      mail = Mail.read_from_string(body)
      
      # Extract email information
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
      
      # Parse date properly
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
          # Try parsing as string
          Time.parse(date_obj.to_s)
        end
      rescue => e
        Time.now
      end
      
      date_str = date.strftime('%Y-%m-%d %H:%M:%S')
      
      # Get body preview
      body_content = begin
        if mail.body
          mail.body.decoded.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace)
        else
          ''
        end
      rescue
        ''
      end
      
      body_preview = body_content.length > 150 ? body_content[0..150] + '...' : body_content
      
      # Check if this email is matched in database
      matched_tracking = ContactTracking.where(
        email_received: true,
        email_from: from
      ).where(
        "email_received_at >= ? AND email_received_at <= ?",
        date - 1.hour,
        date + 1.hour
      ).first
      
      match_status = if matched_tracking
        "✓ MATCHED to ContactTracking ID: #{matched_tracking.id} (#{matched_tracking.customer&.company || 'Unknown'})"
      else
        "⚠ NOT MATCHED in database"
      end
      
      # Determine if this looks like an auto-reply
      is_auto_reply = false
      auto_reply_indicators = []
      
      if subject.downcase.include?('お問い合わせ') || subject.downcase.include?('inquiry') || subject.downcase.include?('contact')
        is_auto_reply = true
        auto_reply_indicators << "Subject contains inquiry keywords"
      end
      
      if subject.downcase.include?('ありがとう') || subject.downcase.include?('thank') || subject.downcase.include?('確認')
        is_auto_reply = true
        auto_reply_indicators << "Subject contains confirmation keywords"
      end
      
      if body_content.include?('お問い合わせ') || body_content.include?('inquiry') || body_content.include?('contact')
        is_auto_reply = true
        auto_reply_indicators << "Body contains inquiry keywords"
      end
      
      # Check if from a company domain (not personal email)
      is_company_email = !from.include?('gmail.com') && 
                         !from.include?('yahoo.com') && 
                         !from.include?('hotmail.com') &&
                         !from.include?('outlook.com') &&
                         from.include?('@')
      
      if is_company_email
        auto_reply_indicators << "From company domain"
      end
      
      # Display email information
      puts "\n[#{index + 1}] Email ID: #{email_id}"
      puts "  From: #{from}"
      puts "  Subject: #{subject}"
      puts "  Date: #{date_str}"
      puts "  Status: #{match_status}"
      
      if is_auto_reply || is_company_email
        puts "  Type: #{is_auto_reply ? '🔔 AUTO-REPLY' : '📧 Company Email'}"
        puts "  Indicators: #{auto_reply_indicators.join(', ')}"
      end
      
      if body_preview.present?
        puts "  Body Preview: #{body_preview.strip}"
      end
      
      puts "  " + "-" * 98
      
    rescue => e
      puts "\n[#{index + 1}] Error reading email #{email_id}: #{e.message}"
      puts "  " + "-" * 98
    end
  end
  
  imap.disconnect
  puts "\n✓ Disconnected from IMAP server"
  
  puts "\n" + "=" * 100
  puts "VERIFICATION SUMMARY"
  puts "=" * 100
  
  # Get database statistics
  total_sent = ContactTracking.where(status: ['送信済', '送信成功']).count
  verified = ContactTracking.where(email_received: true).count
  waiting = ContactTracking.where(status: ['送信済', '送信成功'], email_received: false).count
  
  puts "\nDatabase Statistics:"
  puts "  Total Sent: #{total_sent}"
  puts "  Verified (Email Received): #{verified}"
  puts "  Waiting for Email: #{waiting}"
  puts "  Verification Rate: #{total_sent > 0 ? (verified.to_f / total_sent * 100).round(1) : 0}%"
  
  puts "\n✓ Email check completed!"
  
rescue => e
  puts "\n✗ Error: #{e.message}"
  puts e.backtrace.first(10)
end

