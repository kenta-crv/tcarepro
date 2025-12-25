puts "=== Checking Recent ContactTrackings ==="
ContactTracking.order(id: :desc).limit(5).each do |ct|
  puts "ID: #{ct.id}, Company: #{ct.customer&.company}, Status: #{ct.status}, Scheduled: #{ct.scheduled_date}"
end

puts "\n=== Pending Submissions (自動送信予定) ==="
pending = ContactTracking.where(status: '自動送信予定')
puts "Count: #{pending.count}"
pending.each do |ct|
  puts "ID: #{ct.id}, Company: #{ct.customer&.company}, Scheduled: #{ct.scheduled_date}, URL: #{ct.contact_url}"
end

