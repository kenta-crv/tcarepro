puts "============================================================"
puts "EMAIL VERIFICATION STATUS CHECK"
puts "============================================================"

puts "\n1. Submissions Waiting for Email:"
waiting = ContactTracking.where(status: ['送信済', '送信成功'], email_received: false)
puts "   Count: #{waiting.count}"
if waiting.any?
  puts "   Recent submissions:"
  waiting.order(sended_at: :desc).limit(5).each do |ct|
    puts "     - ID: #{ct.id}, Company: #{ct.customer&.company}, Sent: #{ct.sended_at}"
  end
end

puts "\n2. Verified Emails:"
verified = ContactTracking.where(email_received: true)
puts "   Count: #{verified.count}"
if verified.any?
  puts "   Recent verified emails:"
  verified.order(email_received_at: :desc).limit(5).each do |ct|
    puts "     - ID: #{ct.id}, Company: #{ct.customer&.company}"
    puts "       Subject: #{ct.email_subject}"
    puts "       From: #{ct.email_from}"
    puts "       Received: #{ct.email_received_at}"
  end
else
  puts "   No emails verified yet"
end

puts "\n3. All Recent Submissions (Last 10):"
recent = ContactTracking.order(created_at: :desc).limit(10)
recent.each do |ct|
  status_icon = ct.email_received? ? "✓" : "✗"
  puts "   #{status_icon} ID: #{ct.id}, Status: #{ct.status}, Email: #{ct.email_received? ? 'YES' : 'NO'}, Company: #{ct.customer&.company}"
end

puts "\n============================================================"
