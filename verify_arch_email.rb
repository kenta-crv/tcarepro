# Manually verify Arch Co., Ltd. email now that sended_at is fixed
require_relative 'config/environment'

arch_tracking = ContactTracking.find(22) # We know the ID from previous run

puts "=" * 80
puts "MANUALLY VERIFYING ARCH CO., LTD. EMAIL"
puts "=" * 80
puts "ContactTracking ID: #{arch_tracking.id}"
puts "Company: #{arch_tracking.customer.company}"
puts "Current sended_at: #{arch_tracking.sended_at}"
puts "Email Received: #{arch_tracking.email_received}"
puts

# Email details from user's message
email_subject = "Notice from Arch Co., Ltd."
email_from = "info@archfoods.co.jp"
email_received_at = Time.parse("2024-12-24 16:01:55")

# Manually update the tracking
arch_tracking.update!(
  email_received: true,
  email_received_at: email_received_at,
  email_subject: email_subject,
  email_from: email_from,
  email_matched_at: Time.current
)

puts "✅ Email manually verified!"
puts
arch_tracking.reload
puts "Updated ContactTracking:"
puts "  Email Received: #{arch_tracking.email_received}"
puts "  Email From: #{arch_tracking.email_from}"
puts "  Email Subject: #{arch_tracking.email_subject}"
puts "  Email Received At: #{arch_tracking.email_received_at}"
puts "  Time to Receive: #{(arch_tracking.email_received_at - arch_tracking.sended_at) / 60.0} minutes"
puts "=" * 80

