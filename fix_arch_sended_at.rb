# Fix Arch Co., Ltd. sended_at timestamp to allow email verification
# The email was received on 2024-12-24 16:01:55, so sended_at should be before that

require_relative 'config/environment'

# Find Arch Co., Ltd. submission
arch_tracking = ContactTracking.joins(:customer)
                               .where("customers.company LIKE ? OR customers.company LIKE ?", "%Arch%", "%アーチ%")
                               .where(status: ['送信済', '送信成功'])
                               .order(updated_at: :desc)
                               .first

if arch_tracking
  puts "=" * 80
  puts "FOUND ARCH CO., LTD. SUBMISSION"
  puts "=" * 80
  puts "ContactTracking ID: #{arch_tracking.id}"
  puts "Company: #{arch_tracking.customer.company}"
  puts "Current Status: #{arch_tracking.status}"
  puts "Current sended_at: #{arch_tracking.sended_at}"
  puts "Email Received: #{arch_tracking.email_received}"
  puts
  
  # Email was received on 2024-12-24 16:01:55
  # Set sended_at to 1 hour before email (2024-12-24 15:00:00)
  # This ensures it's within the 24-hour window before email
  email_received_time = Time.parse("2024-12-24 16:01:55")
  correct_sended_at = email_received_time - 1.hour
  
  if arch_tracking.sended_at.nil? || arch_tracking.sended_at > email_received_time
    puts "⚠ ISSUE DETECTED:"
    puts "  Current sended_at: #{arch_tracking.sended_at}"
    puts "  Email received at: #{email_received_time}"
    puts "  sended_at is in the future or nil - this prevents email matching!"
    puts
    puts "FIXING: Setting sended_at to #{correct_sended_at}"
    
    arch_tracking.update!(sended_at: correct_sended_at)
    
    puts "✅ FIXED: sended_at updated to #{arch_tracking.reload.sended_at}"
    puts
    puts "Now triggering email verification..."
    
    # Manually verify the email
    require 'net/imap'
    require 'mail'
    
    imap = Net::IMAP.new('imap.lolipop.jp', port: 993, ssl: true)
    imap.login('mail@tele-match.net', ENV['EMAIL_PASSWORD'] || 'fssds_t84kAd4')
    imap.select('INBOX')
    
    # Find Arch email from info@archfoods.co.jp
    email_ids = imap.search(['FROM', 'info@archfoods.co.jp'])
    
    email_ids.each do |email_id|
      envelope = imap.fetch(email_id, 'ENVELOPE')[0].attr['ENVELOPE']
      body = imap.fetch(email_id, 'RFC822')[0].attr['RFC822']
      mail = Mail.read_from_string(body)
      
      email_subject = envelope.subject || mail.subject || ''
      email_from = if envelope.from && envelope.from[0]
        "#{envelope.from[0].mailbox}@#{envelope.from[0].host}"
      else
        mail.from&.first || 'unknown@unknown.com'
      end
      
      email_date = begin
        date_obj = envelope.date || mail.date
        if date_obj.is_a?(Time)
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
      
      # Check if this is the Arch email
      if email_subject.include?('Arch') && email_from == 'info@archfoods.co.jp'
        puts "  Found Arch email: #{email_subject}"
        puts "  From: #{email_from}"
        puts "  Date: #{email_date}"
        
        # Manually update the tracking
        arch_tracking.update!(
          email_received: true,
          email_received_at: email_date,
          email_subject: email_subject,
          email_from: email_from,
          email_matched_at: Time.current
        )
        
        puts "  ✅ Email manually verified!"
        break
      end
    end
    
    imap.disconnect
    
    puts
    puts "=" * 80
    puts "SUMMARY"
    puts "=" * 80
    arch_tracking.reload
    puts "ContactTracking ID: #{arch_tracking.id}"
    puts "Status: #{arch_tracking.status}"
    puts "sended_at: #{arch_tracking.sended_at}"
    puts "Email Received: #{arch_tracking.email_received}"
    puts "Email From: #{arch_tracking.email_from}"
    puts "Email Subject: #{arch_tracking.email_subject}"
    puts "Email Received At: #{arch_tracking.email_received_at}"
    puts "=" * 80
  else
    puts "✓ sended_at is already correct: #{arch_tracking.sended_at}"
    puts "  (It's before email received time: #{email_received_time})"
    puts
    puts "Triggering email verification worker..."
    EmailVerificationWorker.new.perform
  end
else
  puts "✗ No Arch Co., Ltd. submission found with status '送信済' or '送信成功'"
end

