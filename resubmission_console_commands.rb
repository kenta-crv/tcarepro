# Rails Console Commands for Resubmission
# Copy and paste these commands into Rails console (rails c)

puts "=" * 70
puts "STEP 1: CHECK STATUS"
puts "=" * 70

# All sent submissions
all_sent = ContactTracking.where(status: ['送信済', '送信成功'])
puts "Total sent submissions: #{all_sent.count}"

# With email verification
with_email = all_sent.where(email_received: true)
puts "With email verification: #{with_email.count}"

# Without email verification (need resubmission)
without_email = all_sent.where(email_received: [false, nil])
puts "Without email verification: #{without_email.count}"

# Ready for resubmission (has contact_url)
ready = without_email.where.not(contact_url: nil).where.not(contact_url: '')
puts "Ready for resubmission (has contact_url): #{ready.count}"

puts ""
puts "Sample records (first 5):"
ready.limit(5).each do |ct|
  puts "  ID: #{ct.id}, Company: #{ct.customer&.company}, Sent: #{ct.sended_at}"
end

puts ""
puts "=" * 70
puts "STEP 2: RESET FOR RESUBMISSION"
puts "=" * 70
puts "To reset, run the following commands:"
puts ""
puts "candidates = ContactTracking.where(status: ['送信済', '送信成功']).where(email_received: [false, nil]).where.not(contact_url: nil).where.not(contact_url: '')"
puts "reset_count = 0"
puts "candidates.find_each do |tracking|"
puts "  scheduled_time = Time.current + (reset_count * 2).minutes"
puts "  tracking.update!("
puts "    status: '自動送信予定',"
puts "    scheduled_date: scheduled_time,"
puts "    email_received: false,"
puts "    email_received_at: nil,"
puts "    email_subject: nil,"
puts "    email_from: nil,"
puts "  )"
puts "  reset_count += 1"
puts "  puts \"Reset ID #{tracking.id}\" if reset_count % 10 == 0"
puts "end"
puts "puts \"Reset #{reset_count} submissions\""
puts "=" * 70

