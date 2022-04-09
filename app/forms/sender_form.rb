class SenderForm
  include ActiveModel::Model

  attr_accessor :sender, :year, :month

  delegate :user_name, :email, :rate_limit, to: :sender

  def sended_contact_trackings
    contact_trackings.where(status: '送信済').order(sended_at: :desc)
  end

  def callbacked_contact_trackings
    contact_trackings.where.not(callbacked_at: nil).order(callbacked_at: :desc)
  end

  def sended_rate
    return nil if contact_trackings.count == 0

    sended_contact_trackings.count / contact_trackings.count.to_f * 100
  end

  def callbacked_rate
    return nil if sended_contact_trackings.count == 0

    callbacked_contact_trackings.count / sended_contact_trackings.count.to_f * 100
  end

  def contact_trackings
    sender.contact_trackings.where(created_at: current_month...next_month)
  end

  def prev_month
    current_month - 1.month
  end

  def current_month
    Date.new(year, month)
  end

  def next_month
    current_month + 1.month
  end
end
