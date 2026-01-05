namespace :email do
  desc "Diagnose email verification issues"
  task diagnose: :environment do
    puts "=" * 80
    puts "EMAIL VERIFICATION DIAGNOSTICS"
    puts "=" * 80
    puts
    
    # 1. Check email configuration
    puts "1. EMAIL CONFIGURATION"
    puts "-" * 80
    imap_username = EmailVerificationWorker::IMAP_USERNAME
    puts "IMAP Account: #{imap_username}"
    puts "IMAP Host: #{EmailVerificationWorker::IMAP_HOST}"
    puts "Check Hours Back: #{EmailVerificationWorker::CHECK_HOURS_BACK} hours (#{(EmailVerificationWorker::CHECK_HOURS_BACK / 24.0).round(1)} days)"
    puts
    
    # 2. Check inquiry email addresses
    puts "2. INQUIRY EMAIL ADDRESSES"
    puts "-" * 80
    inquiries = Inquiry.order(updated_at: :desc).limit(10)
    puts "Recent Inquiry Email Addresses:"
    inquiries.each do |inq|
      puts "  - #{inq.from_mail} (Inquiry ID: #{inq.id}, Updated: #{inq.updated_at})"
    end
    puts
    
    # Check if inquiry emails match IMAP account
    unique_emails = Inquiry.pluck(:from_mail).compact.uniq
    puts "Unique inquiry email addresses: #{unique_emails.count}"
    if unique_emails.include?(imap_username)
      puts "✓ At least one inquiry uses the IMAP account email"
    else
      puts "⚠ WARNING: No inquiries use the IMAP account email (#{imap_username})"
      puts "  This means auto-reply emails might be going to different addresses!"
    end
    puts
    
    # 3. Check recent submissions
    puts "3. RECENT SUBMISSIONS"
    puts "-" * 80
    recent_sent = ContactTracking.where(status: ['送信済', '送信成功'])
                                 .order(sended_at: :desc)
                                 .limit(20)
    
    puts "Recent successful submissions: #{recent_sent.count}"
    recent_sent.each do |ct|
      email_status = ct.email_received? ? "✓ EMAIL RECEIVED" : "✗ NO EMAIL"
      puts "  ID: #{ct.id} | Status: #{ct.status} | #{email_status}"
      puts "    Company: #{ct.customer&.company}"
      puts "    Inquiry Email: #{ct.inquiry&.from_mail}"
      puts "    Sent At: #{ct.sended_at}"
      puts "    Email Received At: #{ct.email_received_at || 'N/A'}"
      puts
    end
    puts
    
    # 4. Check waiting for email
    puts "4. SUBMISSIONS WAITING FOR EMAIL"
    puts "-" * 80
    waiting = ContactTracking.where(status: ['送信済', '送信成功'], email_received: false)
    puts "Total waiting: #{waiting.count}"
    
    # Group by time ranges
    now = Time.current
    waiting_by_time = {
      "Last 1 hour" => waiting.where('sended_at >= ?', 1.hour.ago).count,
      "Last 24 hours" => waiting.where('sended_at >= ?', 24.hours.ago).count,
      "Last 7 days" => waiting.where('sended_at >= ?', 7.days.ago).count,
      "Older than 7 days" => waiting.where('sended_at < ?', 7.days.ago).count
    }
    
    waiting_by_time.each do |range, count|
      puts "  #{range}: #{count} submissions"
    end
    puts
    
    # 5. Check email verification worker status
    puts "5. EMAIL VERIFICATION WORKER STATUS"
    puts "-" * 80
    cron_job = Sidekiq::Cron::Job.find('Email Verification - every 10 minutes')
    if cron_job
      puts "✓ Cron job is scheduled"
      puts "  Status: #{cron_job.status}"
      puts "  Last run: #{cron_job.last_time || 'Never'}"
      # Note: next_time method may not be available in all versions
      begin
        puts "  Next run: #{cron_job.next_time || 'N/A'}"
      rescue NoMethodError
        puts "  Next run: N/A (method not available)"
      end
    else
      puts "✗ Cron job not found!"
    end
    puts
    
    # 6. Test IMAP connection
    puts "6. IMAP CONNECTION TEST"
    puts "-" * 80
    begin
      worker = EmailVerificationWorker.new
      imap = worker.send(:connect_to_imap)
      if imap
        puts "✓ IMAP connection successful"
        imap.select('INBOX')
        # Get recent email count
        since_time = Time.now - EmailVerificationWorker::CHECK_HOURS_BACK.hours
        search_criteria = ['SINCE', since_time.strftime('%d-%b-%Y')]
        email_ids = imap.search(search_criteria)
        puts "  Found #{email_ids.length} emails in inbox (last #{EmailVerificationWorker::CHECK_HOURS_BACK} hours)"
        imap.disconnect
      else
        puts "✗ IMAP connection failed"
      end
    rescue => e
      puts "✗ IMAP connection error: #{e.message}"
    end
    puts
    
    # 7. Recommendations
    puts "7. RECOMMENDATIONS"
    puts "-" * 80
    if unique_emails.any? && !unique_emails.include?(imap_username)
      puts "⚠ CRITICAL: Email address mismatch detected!"
      puts "  - IMAP account checks: #{imap_username}"
      puts "  - Inquiry emails use: #{unique_emails.join(', ')}"
      puts "  - SOLUTION: Ensure email forwarding is set up OR update inquiries to use #{imap_username}"
    end
    
    if waiting.count > 0
      puts "⚠ #{waiting.count} submissions are waiting for auto-reply emails"
      puts "  - Run: rake email:verify_manual to manually check for emails"
      puts "  - Check logs for email verification worker activity"
    end
    
    if waiting.where('sended_at >= ?', 7.days.ago).count > 0
      puts "⚠ Recent submissions without emails - verify form submissions are actually working"
    end
    
    puts
    puts "=" * 80
    puts "Diagnostics complete!"
    puts "=" * 80
  end
  
  desc "Manually trigger email verification"
  task verify_manual: :environment do
    puts "Manually triggering email verification..."
    begin
      EmailVerificationWorker.new.perform
      puts "✓ Email verification completed successfully"
    rescue => e
      puts "✗ Email verification failed: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end
  
  desc "Check specific submission email status"
  task :check_submission, [:contact_tracking_id] => :environment do |t, args|
    ct_id = args[:contact_tracking_id]
    unless ct_id
      puts "Usage: rake email:check_submission[CONTACT_TRACKING_ID]"
      exit
    end
    
    ct = ContactTracking.find_by(id: ct_id)
    unless ct
      puts "ContactTracking with ID #{ct_id} not found"
      exit
    end
    
    puts "=" * 80
    puts "SUBMISSION EMAIL STATUS CHECK"
    puts "=" * 80
    puts "ContactTracking ID: #{ct.id}"
    puts "Status: #{ct.status}"
    puts "Email Received: #{ct.email_received? ? 'YES' : 'NO'}"
    puts "Sent At: #{ct.sended_at}"
    puts "Email Received At: #{ct.email_received_at || 'N/A'}"
    puts "Company: #{ct.customer&.company}"
    puts "Inquiry Email: #{ct.inquiry&.from_mail}"
    puts "Contact URL: #{ct.contact_url}"
    puts
    puts "Checking for matching emails..."
    
    # Try to find matching emails
    begin
      worker = EmailVerificationWorker.new
      imap = worker.send(:connect_to_imap)
      if imap
        imap.select('INBOX')
        since_time = ct.sended_at - 1.day if ct.sended_at
        since_time ||= 7.days.ago
        search_criteria = ['SINCE', since_time.strftime('%d-%b-%Y')]
        email_ids = imap.search(search_criteria)
        
        puts "Found #{email_ids.length} emails to check"
        
        email_ids.each do |email_id|
          envelope = imap.fetch(email_id, 'ENVELOPE')[0].attr['ENVELOPE']
          body = imap.fetch(email_id, 'RFC822')[0].attr['RFC822']
          next unless envelope && body
          
          mail = Mail.read_from_string(body)
          email_from = if envelope.from && envelope.from[0]
            "#{envelope.from[0].mailbox}@#{envelope.from[0].host}"
          else
            mail.from&.first&.to_s || 'unknown'
          end
          
          email_subject = envelope.subject || mail.subject || ''
          
          # Check if this email matches
          if worker.send(:matches_submission?, ct, email_from, email_subject, mail)
            puts "✓ FOUND MATCHING EMAIL!"
            puts "  From: #{email_from}"
            puts "  Subject: #{email_subject}"
            puts "  Date: #{envelope.date || mail.date}"
          end
        end
        
        imap.disconnect
      end
    rescue => e
      puts "Error checking emails: #{e.message}"
    end
    
    puts "=" * 80
  end
  
  desc "Reset submissions without email for resubmission"
  task reset_no_email: :environment do
    puts "This is a shortcut to: rake resubmission:reset[only_no_email]"
    puts "Running resubmission:reset..."
    Rake::Task['resubmission:reset'].invoke('only_no_email', nil)
  end
end

