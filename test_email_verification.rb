#!/usr/bin/env ruby
# Test script for email verification system

puts "=" * 60
puts "EMAIL VERIFICATION SYSTEM TEST"
puts "=" * 60

# Check database fields
puts "\n1. Database Fields Check:"
email_fields = ContactTracking.column_names.grep(/email/)
if email_fields.any?
  puts "   ✓ Email verification fields exist: #{email_fields.join(', ')}"
else
  puts "   ✗ Email verification fields NOT found!"
end

# Check for submissions waiting for email
puts "\n2. Submissions Waiting for Email:"
waiting = ContactTracking.where(status: ['送信済', '送信成功'], email_received: false)
puts "   Count: #{waiting.count}"
if waiting.any?
  puts "   Recent submissions:"
  waiting.order(sended_at: :desc).limit(5).each do |ct|
    puts "     - ID: #{ct.id}, Company: #{ct.customer&.company}, Sent: #{ct.sended_at}"
  end
else
  puts "   No submissions waiting for email verification"
end

# Check for verified emails
puts "\n3. Verified Emails:"
verified = ContactTracking.where(email_received: true)
puts "   Count: #{verified.count}"
if verified.any?
  puts "   Recent verifications:"
  verified.order(email_received_at: :desc).limit(5).each do |ct|
    puts "     - ID: #{ct.id}, Company: #{ct.customer&.company}"
    puts "       Email from: #{ct.email_from}"
    puts "       Subject: #{ct.email_subject}"
    puts "       Received at: #{ct.email_received_at}"
  end
else
  puts "   No emails verified yet"
end

# Check Sidekiq cron job
puts "\n4. Sidekiq Cron Job:"
begin
  job = Sidekiq::Cron::Job.find('Email Verification - every 10 minutes')
  if job
    puts "   ✓ Cron job found: '#{job.name}'"
    puts "   Schedule: #{job.cron}"
    puts "   Status: #{job.status}"
    puts "   Last run: #{job.last_run_time}"
    puts "   Next run: #{job.next_run_time}"
  else
    puts "   ✗ Cron job NOT found!"
  end
rescue => e
  puts "   ⚠ Could not check cron job: #{e.message}"
  puts "   (Sidekiq may need to be restarted)"
end

puts "\n" + "=" * 60
puts "To manually test email verification, run:"
puts "  EmailVerificationWorker.perform_async"
puts "=" * 60

