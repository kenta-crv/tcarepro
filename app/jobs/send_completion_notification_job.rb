class EmailSendingJob < ApplicationJob
    queue_as :default
  
    def perform(inquiry_id, customer_ids)
      inquiry = Inquiry.find(inquiry_id)
  
      # 顧客に対してメールを送信
      customer_ids.each do |customer_id|
        customer = Customer.find(customer_id)
        CustomerMailer.send_inquiry(customer, inquiry).deliver_now
      end
  
      # すべてのメール送信完了後に通知
      CustomerMailer.completion_notification.deliver_now
    end
  end
  