# app/services/send_emails_service.rb
class SendEmailsService
    def self.schedule_sending
      inquiry_id = # 送信対象のInquiry ID
      customers = Customer.where("TRIM(mail) IS NOT NULL AND TRIM(mail) != ''").limit(80)
      customer_ids = customers.pluck(:id)
  
      SendEmailsJob.perform_later(customer_ids, inquiry_id) if customer_ids.any?
    end
  end
  