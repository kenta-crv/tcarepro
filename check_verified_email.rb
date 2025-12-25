ct = ContactTracking.find(2)
puts "============================================================"
puts "VERIFIED EMAIL DETAILS"
puts "============================================================"
puts "ID: #{ct.id}"
puts "Company: #{ct.customer&.company}"
puts "Email Subject: #{ct.email_subject}"
puts "Email From: #{ct.email_from}"
puts "Email Received At: #{ct.email_received_at}"
puts "Submission Sent At: #{ct.sended_at}"
if ct.email_receipt_duration
  puts "Time to receive: #{(ct.email_receipt_duration / 60.0).round(2)} minutes"
end
puts "============================================================"

