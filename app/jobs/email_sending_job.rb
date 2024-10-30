class EmailSendingJob < ApplicationJob
  queue_as :default
  BATCH_LIMIT = 280

  def perform(inquiry_id, customer_ids, retries, from_email)
    inquiry = Inquiry.find(inquiry_id)
    
    # 上限の280件に制限
    customer_ids.first(BATCH_LIMIT).each do |customer_id|
      customer = Customer.find(customer_id)
      
      begin
        # 送信処理
        send_inquiry(customer, inquiry, from_email)
        
        # 成功時に履歴を追加
        EmailHistory.create!(
          customer_id: customer.id,
          inquiry_id: inquiry.id,
          sent_at: Time.current,
          status: "success"
        )

      rescue => e
        # エラー時の履歴
        EmailHistory.create!(
          customer_id: customer.id,
          inquiry_id: inquiry.id,
          sent_at: Time.current,
          status: "failed",
          error_message: e.message
        )
        logger.error "Failed to send email to #{customer.mail}: #{e.message}"
      end
    end

    # 残りの顧客がある場合は1時間後に再度予約
    remaining_ids = customer_ids.drop(BATCH_LIMIT)
    logger.info "Remaining customer_ids for next batch: #{remaining_ids}"
    if remaining_ids.any?
      next_send_time = Time.zone.now + 1.hour
      EmailSendingJob.set(wait_until: next_send_time).perform_later(inquiry_id, remaining_ids, retries + 1, from_email)
    else
      # すべてのメール送信後に通知を行う場合はここに追加
      completion_notification
    end
  end

  private

  def send_inquiry(customer, inquiry, from_email)
    CustomerMailer.send_inquiry(customer, inquiry, from_email).deliver_now
  end

  def completion_notification
    # 送信完了通知を行うロジック（必要に応じて実装）
    CustomerMailer.completion_notification.deliver_now
  end
end
