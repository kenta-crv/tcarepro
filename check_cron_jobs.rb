require 'sidekiq-cron'

puts "=" * 60
puts "CHECKING SIDEKIQ CRON JOBS"
puts "=" * 60

begin
  jobs = Sidekiq::Cron::Job.all
  puts "\nFound #{jobs.count} cron job(s):\n"
  
  if jobs.any?
    jobs.each do |job|
      puts "  Name: #{job.name}"
      puts "  Class: #{job.klass}"
      puts "  Cron: #{job.cron}"
      puts "  Status: #{job.status}"
      puts "  Last run: #{job.last_run_time rescue 'N/A'}"
      puts "  Next run: #{job.next_run_time rescue 'N/A'}"
      puts "-" * 60
    end
  else
    puts "  No cron jobs found!"
    puts "\n  Creating email verification job..."
    Sidekiq::Cron::Job.create(
      name: 'Email Verification - every 10 minutes',
      cron: '*/10 * * * *',
      class: 'EmailVerificationWorker'
    )
    puts "  ✓ Job created!"
  end
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(5)
end

puts "\n" + "=" * 60

