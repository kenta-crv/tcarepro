class SendEmailsService
  def self.schedule_sending(inquiry_id, from_email)
    customers = Customer.where("TRIM(mail) IS NOT NULL AND TRIM(mail) != ''").limit(80)
    customer_ids = customers.pluck(:id)

    EmailSendingJob.perform_later(inquiry_id, customer_ids, from_email) if customer_ids.any?
  end
end
