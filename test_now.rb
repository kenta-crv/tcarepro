ct = ContactTracking.where(status: '自動送信予定').order(id: :desc).first

if ct
  old_time = ct.scheduled_date
  # Set to 2 minutes from now
  ct.update!(scheduled_date: 2.minutes.from_now)
  puts "✓ Updated scheduled time for: #{ct.customer&.company}"
  puts "  Old time: #{old_time}"
  puts "  New time: #{ct.scheduled_date}"
  puts "  Contact URL: #{ct.contact_url}"
  puts "  ContactTracking ID: #{ct.id}"
  puts "\n✅ Python service will pick this up in the next Reservation Check!!! (within 1 minute)"
  puts "   Watch your Python bootio.py window for execution!"
else
  puts "✗ No pending submissions found"
end

