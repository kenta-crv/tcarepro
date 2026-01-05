namespace :resubmission do
  desc "Check status of submissions that can be resubmitted"
  task check_status: :environment do
    puts "=" * 80
    puts "RESUBMISSION STATUS CHECK"
    puts "=" * 80
    puts

    # All sent submissions
    all_sent = ContactTracking.where(status: ['送信済', '送信成功'])
    puts "1. TOTAL SENT SUBMISSIONS"
    puts "-" * 80
    puts "Total: #{all_sent.count}"
    puts

    # With email verification
    with_email = all_sent.where(email_received: true)
    puts "2. WITH EMAIL VERIFICATION"
    puts "-" * 80
    puts "Count: #{with_email.count}"
    puts "Percentage: #{all_sent.count > 0 ? (with_email.count.to_f / all_sent.count * 100).round(1) : 0}%"
    puts

    # Without email verification
    without_email = all_sent.where(email_received: [false, nil])
    puts "3. WITHOUT EMAIL VERIFICATION (Candidates for resubmission)"
    puts "-" * 80
    puts "Total: #{without_email.count}"
    puts

    # Ready for resubmission (has contact_url)
    with_url = without_email.where.not(contact_url: nil).where.not(contact_url: '')
    without_url = without_email.where(contact_url: [nil, ''])

    puts "4. RESUBMISSION READINESS"
    puts "-" * 80
    puts "Ready (has contact_url): #{with_url.count}"
    puts "Not ready (missing contact_url): #{without_url.count}"
    puts

    # Breakdown by date
    if with_url.any?
      puts "5. BREAKDOWN BY SENT DATE (Ready for resubmission)"
      puts "-" * 80
      with_url.group_by { |ct| ct.sended_at&.to_date }
             .sort_by { |date, _| date || Date.new(1900, 1, 1) }
             .reverse
             .first(10)
             .each do |date, records|
        puts "  #{date || 'No date'}: #{records.count} submissions"
      end
      puts
    end

    # Sample records
    if with_url.any?
      puts "6. SAMPLE RECORDS (First 5 ready for resubmission)"
      puts "-" * 80
      with_url.limit(5).each do |ct|
        puts "  ID: #{ct.id}"
        puts "    Company: #{ct.customer&.company}"
        puts "    Sent: #{ct.sended_at}"
        puts "    URL: #{ct.contact_url&.truncate(60)}"
        puts
      end
    end

    puts "=" * 80
    puts "To reset these for resubmission, run:"
    puts "  rake resubmission:reset                    # Reset all without email"
    puts "  rake resubmission:reset[only_no_email]     # Reset only those without email (same as above)"
    puts "  rake resubmission:reset[all]               # Reset ALL sent submissions"
    puts "  rake resubmission:reset[ids,1,2,3]         # Reset specific IDs"
    puts "=" * 80
  end

  desc "Reset submissions for resubmission"
  task :reset, [:mode, :ids] => :environment do |t, args|
    mode = args[:mode] || 'only_no_email'
    ids_param = args[:ids]

    puts "=" * 80
    puts "RESET SUBMISSIONS FOR RESUBMISSION"
    puts "=" * 80
    puts "Mode: #{mode}"
    puts

    # Determine which submissions to reset
    candidates = case mode
    when 'all'
      # Reset ALL sent submissions
      ContactTracking.where(status: ['送信済', '送信成功'])
                    .where.not(contact_url: nil)
                    .where.not(contact_url: '')
    when 'only_no_email', 'default'
      # Reset only those without email verification
      ContactTracking.where(status: ['送信済', '送信成功'])
                    .where(email_received: [false, nil])
                    .where.not(contact_url: nil)
                    .where.not(contact_url: '')
    when 'ids'
      # Reset specific IDs
      if ids_param.blank?
        puts "Error: IDs mode requires comma-separated IDs"
        puts "Usage: rake resubmission:reset[ids,1,2,3]"
        exit 1
      end
      ids = ids_param.split(',').map(&:strip).map(&:to_i)
      ContactTracking.where(id: ids)
                    .where.not(contact_url: nil)
                    .where.not(contact_url: '')
    else
      puts "Error: Unknown mode '#{mode}'"
      puts "Valid modes: all, only_no_email, ids"
      exit 1
    end

    puts "Found #{candidates.count} submissions to reset"
    puts

    if candidates.count == 0
      puts "No submissions found to reset."
      exit
    end

    # Show breakdown
    puts "Breakdown:"
    puts "  With email: #{candidates.where(email_received: true).count}"
    puts "  Without email: #{candidates.where(email_received: [false, nil]).count}"
    puts

    # Ask for confirmation
    print "Do you want to reset these submissions for resubmission? (yes/no): "
    confirmation = STDIN.gets.chomp.downcase

    unless confirmation == 'yes' || confirmation == 'y'
      puts "Operation cancelled."
      exit
    end

    puts
    puts "Resetting submissions..."
    puts "Submissions will be scheduled 2 minutes apart starting from now."
    puts

    reset_count = 0
    error_count = 0
    start_time = Time.current

    # Reset each submission
    candidates.find_each do |tracking|
      begin
        # Check if can be reset
        unless tracking.can_resubmit?
          puts "Skipping ID #{tracking.id}: Cannot be resubmitted (status: #{tracking.status}, url: #{tracking.contact_url.present? ? 'present' : 'missing'})"
          next
        end

        # Calculate scheduled time (2 minutes apart)
        scheduled_time = start_time + (reset_count * 2).minutes
        
        # Reset using model method
        tracking.reset_for_resubmission!(scheduled_date: scheduled_time)
        
        reset_count += 1
        if reset_count % 10 == 0
          print "."
          STDOUT.flush
        end
      rescue => e
        error_count += 1
        puts "\nError resetting ID #{tracking.id}: #{e.message}"
        puts e.backtrace.first(3).join("\n")
      end
    end

    puts
    puts
    puts "=" * 80
    puts "RESET COMPLETE"
    puts "=" * 80
    puts "Successfully reset: #{reset_count} submissions"
    puts "Errors: #{error_count} submissions"
    puts

    if reset_count > 0
      first_scheduled = start_time
      last_scheduled = start_time + (reset_count - 1) * 2.minutes
      puts "Scheduling:"
      puts "  First submission: #{first_scheduled.strftime('%Y-%m-%d %H:%M:%S')}"
      puts "  Last submission: #{last_scheduled.strftime('%Y-%m-%d %H:%M:%S')}"
      puts "  Total duration: #{(reset_count * 2 / 60.0).round(1)} hours"
      puts
    end

    puts "Next steps:"
    puts "1. Make sure Python bootio.py service is running:"
    puts "   cd autoform && python bootio.py"
    puts
    puts "2. Monitor submissions in the Rails dashboard"
    puts
    puts "3. After submissions complete, check for emails:"
    puts "   rake email:verify_manual"
    puts
    puts "4. View email verification dashboard:"
    puts "   /senders/:sender_id/okurite/email_verification"
    puts "=" * 80
  end

  desc "Reset a single submission by ID"
  task :reset_one, [:id] => :environment do |t, args|
    id = args[:id]
    
    unless id
      puts "Usage: rake resubmission:reset_one[CONTACT_TRACKING_ID]"
      exit 1
    end

    tracking = ContactTracking.find_by(id: id)
    unless tracking
      puts "ContactTracking with ID #{id} not found"
      exit 1
    end

    puts "=" * 80
    puts "RESET SINGLE SUBMISSION"
    puts "=" * 80
    puts "ID: #{tracking.id}"
    puts "Company: #{tracking.customer&.company}"
    puts "Current Status: #{tracking.status}"
    puts "Email Received: #{tracking.email_received? ? 'Yes' : 'No'}"
    puts "Contact URL: #{tracking.contact_url&.truncate(60)}"
    puts

    unless tracking.can_resubmit?
      puts "Cannot reset this submission:"
      puts "  - Status must be '送信済' or '送信成功' (current: #{tracking.status})"
      puts "  - Must have contact_url (current: #{tracking.contact_url.present? ? 'present' : 'missing'})"
      exit 1
    end

    print "Reset this submission? (yes/no): "
    confirmation = STDIN.gets.chomp.downcase

    unless confirmation == 'yes' || confirmation == 'y'
      puts "Operation cancelled."
      exit
    end

    tracking.reset_for_resubmission!
    puts
    puts "✓ Successfully reset submission ID #{tracking.id}"
    puts "  New status: #{tracking.status}"
    puts "  Scheduled date: #{tracking.scheduled_date}"
    puts
    puts "The Python bootio.py service will process this automatically."
  end
end
