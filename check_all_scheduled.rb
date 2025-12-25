# Check all scheduled submissions directly from database
require_relative 'config/environment'

puts "=" * 80
puts "CHECKING ALL SCHEDULED SUBMISSIONS"
puts "=" * 80
puts

# Get all scheduled submissions
scheduled = ContactTracking.where(status: '自動送信予定')
                          .where('scheduled_date > ?', Time.current)
                          .order(scheduled_date: :asc)
                          .includes(:customer)

puts "SCHEDULED SUBMISSIONS (Future):"
puts "-" * 80

if scheduled.any?
  scheduled.each do |tracking|
    company_name = tracking.customer&.company || 'Unknown'
    puts "[ID: #{tracking.id}] #{company_name}"
    puts "  Status: #{tracking.status}"
    puts "  Scheduled Date: #{tracking.scheduled_date}"
    puts "  Sent At: #{tracking.sended_at || 'Not set'}"
    puts "  Contact URL: #{tracking.contact_url&.truncate(60)}"
    puts
  end
else
  puts "No scheduled submissions found."
  puts
end

puts "=" * 80
puts "RECENTLY SENT SUBMISSIONS (Last 24 hours):"
puts "-" * 80

# Get recently sent submissions
recent_sent = ContactTracking.where(status: ['送信済', '送信成功'])
                             .where('sended_at > ?', 24.hours.ago)
                             .order(sended_at: :desc)
                             .includes(:customer)

if recent_sent.any?
  recent_sent.each do |tracking|
    company_name = tracking.customer&.company || 'Unknown'
    elapsed = (Time.current - tracking.sended_at) / 3600.0
    puts "[ID: #{tracking.id}] #{company_name}"
    puts "  Status: #{tracking.status}"
    puts "  Sent At: #{tracking.sended_at}"
    puts "  Elapsed: #{elapsed.round(1)} hours ago"
    puts "  Email Received: #{tracking.email_received? ? 'Yes' : 'No'}"
    puts "  Contact URL: #{tracking.contact_url&.truncate(60)}"
    puts
  end
else
  puts "No recently sent submissions found."
  puts
end

puts "=" * 80
puts "SUBMISSIONS WITH FUTURE sended_at (SHOULD BE SCHEDULED):"
puts "-" * 80

# Check for submissions marked as "sent" but with future sended_at
future_sent = ContactTracking.where(status: ['送信済', '送信成功'])
                             .where('sended_at > ?', Time.current)
                             .order(sended_at: :asc)
                             .includes(:customer)

if future_sent.any?
  future_sent.each do |tracking|
    company_name = tracking.customer&.company || 'Unknown'
    puts "[ID: #{tracking.id}] #{company_name}"
    puts "  Status: #{tracking.status} (but sended_at is in future!)"
    puts "  Scheduled Date: #{tracking.scheduled_date || 'Not set'}"
    puts "  Sent At: #{tracking.sended_at} (FUTURE - this is wrong!)"
    puts "  Contact URL: #{tracking.contact_url&.truncate(60)}"
    puts "  → This submission shows as 'Scheduled' in dashboard because sended_at is future"
    puts
  end
else
  puts "No submissions with future sended_at found."
  puts
end

puts "=" * 80
puts "SUMMARY"
puts "=" * 80
puts "Scheduled (status='自動送信予定' with future scheduled_date): #{scheduled.count}"
puts "Recently Sent (last 24 hours): #{recent_sent.count}"
puts "Marked 'Sent' but sended_at is future: #{future_sent.count}"
puts "=" * 80

