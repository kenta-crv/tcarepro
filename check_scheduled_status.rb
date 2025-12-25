# Check which submissions are actually scheduled vs already sent
ContactTracking.where(status: ['自動送信予定', '送信済', '送信成功'])
              .where(email_received: false)
              .order(id: :desc)
              .limit(15)
              .each do |ct|
  elapsed = ct.sended_at ? ((Time.current - ct.sended_at) / 3600.0) : nil
  elapsed_str = if ct.sended_at.nil?
    "No sended_at"
  elsif elapsed && elapsed < 0
    "FUTURE (Scheduled)"
  elsif elapsed && elapsed < 1
    "#{(elapsed * 60).round(0)} minutes ago"
  elsif elapsed && elapsed < 24
    "#{elapsed.round(1)} hours ago"
  else
    "#{(elapsed / 24.0).round(1)} days ago"
  end
  
  puts "ID: #{ct.id} | Status: #{ct.status} | Company: #{ct.customer&.company}"
  puts "  Scheduled: #{ct.scheduled_date}"
  puts "  Sent At: #{ct.sended_at}"
  puts "  Elapsed: #{elapsed_str}"
  puts "  URL: #{ct.contact_url}"
  puts "-" * 80
end

