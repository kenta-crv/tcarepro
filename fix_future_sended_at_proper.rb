# Fix submissions that are marked as "Sent" but have future sended_at timestamps
# Set them to actual past times based on when they were likely executed
require_relative 'config/environment'

puts "=" * 80
puts "FIXING FUTURE sended_at TIMESTAMPS (PROPERLY)"
puts "=" * 80
puts

# Find all submissions marked as "Sent" but with future sended_at
future_sent = ContactTracking.where(status: ['送信済', '送信成功'])
                             .where('sended_at > ?', Time.current)
                             .order(sended_at: :asc)
                             .includes(:customer)

if future_sent.any?
  puts "Found #{future_sent.count} submissions with future sended_at timestamps"
  puts
  puts "FIXING: Setting sended_at to actual past execution time"
  puts "-" * 80
  puts
  
  fixed_count = 0
  current_time = Time.current
  
  future_sent.each do |tracking|
    company_name = tracking.customer&.company || 'Unknown'
    
    # Determine correct sended_at time
    # Use updated_at if it's in the past, otherwise use 1 hour ago from now
    if tracking.updated_at && tracking.updated_at < current_time
      # Use updated_at as it likely represents when the status was changed to "送信済"
      correct_sended_at = tracking.updated_at
    elsif tracking.scheduled_date && tracking.scheduled_date < current_time
      # Use scheduled_date if it's in the past
      correct_sended_at = tracking.scheduled_date
    else
      # Fallback: set to 1 hour ago from current time
      correct_sended_at = current_time - 1.hour
    end
    
    old_sended_at = tracking.sended_at
    
    tracking.update!(sended_at: correct_sended_at)
    
    fixed_count += 1
    elapsed = (current_time - correct_sended_at) / 3600.0
    puts "[#{fixed_count}] Fixed: #{company_name} (ID: #{tracking.id})"
    puts "    Old sended_at: #{old_sended_at} (FUTURE)"
    puts "    New sended_at: #{tracking.reload.sended_at} (#{elapsed.round(1)} hours ago)"
    puts "    Status: #{tracking.status}"
    puts
  end
  
  puts "=" * 80
  puts "✅ Successfully fixed #{fixed_count} submissions!"
  puts "=" * 80
  puts
  puts "These submissions will now show correctly in the dashboard:"
  puts "  - They will show as 'Sent' with correct elapsed time"
  puts "  - Email verification will work correctly"
  puts "  - They will no longer appear as 'Scheduled'"
  puts "=" * 80
else
  puts "No submissions with future sended_at timestamps found."
  puts "=" * 80
end

