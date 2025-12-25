# Verify actual status of submissions - check if they're scheduled or already sent
require_relative 'config/environment'

puts "=" * 80
puts "VERIFYING SUBMISSION STATUS"
puts "=" * 80
puts

# Companies to check
companies_to_check = [
  'Japan Logicom Co., Ltd.',
  'Co., Ltd.',  # This might be partial - need to search
  'J-Wing Co., Ltd.',
  'Omi Manufacturing Co., Ltd.',
  'Kikotec Co., Ltd.',
  'Yamada Foods Co., Ltd.',
  'Million Enterprise Co., Ltd.',
  'AC Chemical Co., Ltd.',
  'Tomoe Shokai Co., Ltd.'
]

companies_to_check.each do |company_name|
  # Search for the company (handle partial names)
  if company_name == 'Co., Ltd.'
    # This is likely a partial name - search for companies with this pattern
    customers = Customer.where("company LIKE ?", "%Co., Ltd.%")
                        .where.not(company: companies_to_check.reject { |c| c == 'Co., Ltd.' })
                        .limit(5)
  else
    customers = Customer.where("company LIKE ?", "%#{company_name}%")
  end
  
  if customers.any?
    customers.each do |customer|
      # Find the latest ContactTracking for this customer
      tracking = ContactTracking.where(customer_id: customer.id)
                                .order(updated_at: :desc, id: :desc)
                                .first
      
      if tracking
        puts "[#{customer.company}]"
        puts "  ContactTracking ID: #{tracking.id}"
        puts "  Status: #{tracking.status}"
        puts "  Scheduled Date: #{tracking.scheduled_date}"
        puts "  Sent At: #{tracking.sended_at}"
        puts "  Email Received: #{tracking.email_received? ? 'Yes' : 'No'}"
        puts "  Contact URL: #{tracking.contact_url&.truncate(60)}"
        
        # Determine actual state
        if tracking.status == '自動送信予定'
          if tracking.scheduled_date && tracking.scheduled_date > Time.current
            puts "  → ACTUALLY SCHEDULED (will run at #{tracking.scheduled_date})"
          elsif tracking.scheduled_date && tracking.scheduled_date <= Time.current
            puts "  → SCHEDULED BUT TIME HAS PASSED (should have run already)"
          else
            puts "  → SCHEDULED BUT NO SCHEDULED_DATE SET"
          end
        elsif tracking.status == '送信済' || tracking.status == '送信成功'
          if tracking.sended_at
            elapsed = (Time.current - tracking.sended_at) / 3600.0
            puts "  → ACTUALLY SENT (#{elapsed.round(1)} hours ago at #{tracking.sended_at})"
          else
            puts "  → MARKED AS SENT BUT NO sended_at TIMESTAMP"
          end
        elsif tracking.status == '処理中'
          puts "  → CURRENTLY PROCESSING"
        else
          puts "  → ERROR STATUS: #{tracking.status}"
        end
        puts
      else
        puts "[#{customer.company}]"
        puts "  → NO ContactTracking RECORD FOUND"
        puts
      end
    end
  else
    puts "[#{company_name}]"
    puts "  → COMPANY NOT FOUND IN DATABASE"
    puts
  end
end

puts "=" * 80
puts "SUMMARY"
puts "=" * 80

# Count by status
scheduled_count = ContactTracking.where(status: '自動送信予定')
                                 .where('scheduled_date > ?', Time.current)
                                 .count

sent_count = ContactTracking.where(status: ['送信済', '送信成功'])
                            .where.not(sended_at: nil)
                            .count

processing_count = ContactTracking.where(status: '処理中').count

error_count = ContactTracking.where("status LIKE ?", "%エラー%").count

puts "Total Scheduled (future): #{scheduled_count}"
puts "Total Sent: #{sent_count}"
puts "Total Processing: #{processing_count}"
puts "Total Errors: #{error_count}"
puts "=" * 80

