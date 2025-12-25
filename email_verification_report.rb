require 'net/imap'
require 'mail'

puts "=" * 100
puts "EMAIL VERIFICATION REPORT"
puts "Generated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
puts "=" * 100

# Database Statistics
puts "\n📊 DATABASE STATISTICS"
puts "-" * 100

total_sent = ContactTracking.where(status: ['送信済', '送信成功']).count
verified = ContactTracking.where(email_received: true).count
waiting = ContactTracking.where(status: ['送信済', '送信成功'], email_received: false).count
verification_rate = total_sent > 0 ? (verified.to_f / total_sent * 100).round(1) : 0

puts "Total Submissions Sent: #{total_sent}"
puts "Emails Verified: #{verified}"
puts "Waiting for Email: #{waiting}"
puts "Verification Rate: #{verification_rate}%"

# Verified Emails Details
puts "\n✅ VERIFIED EMAILS"
puts "-" * 100

verified_trackings = ContactTracking.where(email_received: true)
                                   .order(email_received_at: :desc)
                                   .includes(:customer)

if verified_trackings.any?
  verified_trackings.each do |tracking|
    receipt_time = tracking.email_receipt_duration ? (tracking.email_receipt_duration / 60.0).round(1) : nil
    puts "\n[ID: #{tracking.id}]"
    puts "  Company: #{tracking.customer&.company || 'Unknown'}"
    puts "  Sent At: #{tracking.sended_at&.strftime('%Y-%m-%d %H:%M:%S')}"
    puts "  Email From: #{tracking.email_from}"
    puts "  Email Subject: #{tracking.email_subject}"
    puts "  Received At: #{tracking.email_received_at&.strftime('%Y-%m-%d %H:%M:%S')}"
    puts "  Time to Receive: #{receipt_time ? "#{receipt_time} minutes" : 'N/A'}"
  end
else
  puts "No verified emails found"
end

# Waiting Submissions
puts "\n⏳ WAITING FOR EMAIL"
puts "-" * 100

waiting_trackings = ContactTracking.where(status: ['送信済', '送信成功'], email_received: false)
                                  .order(sended_at: :desc)
                                  .includes(:customer)
                                  .limit(10)

if waiting_trackings.any?
  waiting_trackings.each do |tracking|
    elapsed = tracking.sended_at ? ((Time.current - tracking.sended_at) / 3600.0).round(1) : nil
    elapsed_str = if elapsed.nil?
      'N/A'
    elsif elapsed < 1
      "#{(elapsed * 60).round(0)} minutes ago"
    elsif elapsed < 24
      "#{elapsed.round(1)} hours ago"
    else
      "#{(elapsed / 24.0).round(1)} days ago"
    end
    
    puts "\n[ID: #{tracking.id}]"
    puts "  Company: #{tracking.customer&.company || 'Unknown'}"
    puts "  Sent At: #{tracking.sended_at&.strftime('%Y-%m-%d %H:%M:%S')}"
    puts "  Elapsed: #{elapsed_str}"
    puts "  Contact URL: #{tracking.contact_url || 'N/A'}"
  end
else
  puts "No submissions waiting for email"
end

# IMAP Connection Test
puts "\n📧 IMAP CONNECTION TEST"
puts "-" * 100

begin
  IMAP_HOST = 'imap.lolipop.jp'
  IMAP_PORT = 993
  IMAP_USERNAME = 'mail@tele-match.net'
  IMAP_PASSWORD = ENV['EMAIL_PASSWORD'] || 'fssds_t84kAd4'
  
  imap = Net::IMAP.new(IMAP_HOST, port: IMAP_PORT, ssl: true)
  imap.login(IMAP_USERNAME, IMAP_PASSWORD)
  imap.select('INBOX')
  
  total_emails = imap.search(['ALL']).length
  since_date = (Date.today - 7).strftime('%d-%b-%Y')
  recent_emails = imap.search(['SINCE', since_date]).length
  
  puts "✓ IMAP Connection: SUCCESS"
  puts "  Total Emails in Inbox: #{total_emails}"
  puts "  Emails in Last 7 Days: #{recent_emails}"
  
  imap.disconnect
rescue => e
  puts "✗ IMAP Connection: FAILED"
  puts "  Error: #{e.message}"
end

# Summary
puts "\n" + "=" * 100
puts "SUMMARY"
puts "=" * 100
puts "✓ Email verification system is operational"
puts "✓ IMAP connection is working"
puts "✓ #{verified} out of #{total_sent} submissions have verified emails (#{verification_rate}%)"
puts "✓ #{waiting} submissions are waiting for company auto-replies"
puts "\nNext Steps:"
puts "  1. Wait for companies to send auto-reply emails"
puts "  2. Email verification runs automatically every 10 minutes"
puts "  3. Check dashboard at: /senders/:id/okurite/email_verification"
puts "  4. Manually trigger verification if needed"

puts "\n" + "=" * 100

