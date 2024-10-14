class EmailSendingJob < ApplicationJob
  queue_as :default

  def perform(inquiry_id, customer_ids, index = 0)
    inquiry = Inquiry.find(inquiry_id)

    # 指定されたインデックスが顧客数を超えている場合は終了
    return if index >= customer_ids.size

    customer_id = customer_ids[index]
    customer = Customer.find(customer_id)

    # メールを送信
    CustomerMailer.send_inquiry(customer, inquiry).deliver_later

    # 次のインデックスを計算し、45秒後に再実行
    EmailSendingJob.set(wait: 45.seconds).perform_later(inquiry_id, customer_ids, index + 1)
  end
end