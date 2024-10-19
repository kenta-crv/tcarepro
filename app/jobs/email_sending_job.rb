class EmailSendingJob < ApplicationJob
  queue_as :default

  def perform(inquiry_id, customer_ids, index = 0, from_email)
    Rails.logger.info "Starting EmailSendingJob with inquiry_id: #{inquiry_id}, customer_ids: #{customer_ids}, index: #{index}, from_email: #{from_email}"
  
    inquiry = Inquiry.find_by(id: inquiry_id)
    if inquiry.nil?
      Rails.logger.error "Inquiry not found for ID: #{inquiry_id}"
      return
    end
  
    # 指定されたインデックスが顧客数を超えている場合は終了
    return if index >= customer_ids.size
  
    customer_id = customer_ids[index]
    customer = Customer.find_by(id: customer_id)
  
    if customer.nil?
      Rails.logger.error "Customer not found for ID: #{customer_id}"
      return
    end
  
    # メールを送信
    if CustomerMailer.send_inquiry(customer, inquiry, from_email).deliver_later
      Rails.logger.info "Email sent to Customer ID: #{customer_id}"
    else
      Rails.logger.error "Failed to send email to Customer ID: #{customer_id}"
    end
  
    # 次のインデックスを計算し、45秒後に再実行
    Rails.logger.info "Scheduling next email for Customer ID: #{customer_ids[index + 1]}" if index + 1 < customer_ids.size
    EmailSendingJob.set(wait: 45.seconds).perform_later(inquiry_id, customer_ids, index + 1, from_email)

  end
  
end
