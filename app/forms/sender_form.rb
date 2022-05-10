class SenderForm
  include ActiveModel::Model

  attr_accessor :sender, :year, :month

  delegate :user_name, :email, :rate_limit, to: :sender

  def sended_contact_trackings
    monthly_contact_trackings.where(status: '送信済').order(sended_at: :desc)
  end

  def weekly_sended_contact_trackings
    weekly_contact_trackings.where(status: '送信済').order(sended_at: :desc)
  end

  def daily_sended_contact_trackings
    daily_contact_trackings.where(status: '送信済').order(sended_at: :desc)
  end

  def callbacked_contact_trackings
    monthly_contact_trackings.where.not(callbacked_at: nil).order(callbacked_at: :desc)
  end

  def sended_rate
    return nil if monthly_contact_trackings.count == 0

    sended_contact_trackings.count / monthly_contact_trackings.count.to_f * 100
  end

  def callbacked_rate
    return nil if sended_contact_trackings.count == 0

    callbacked_contact_trackings.count / sended_contact_trackings.count.to_f * 100
  end

  def monthly_contact_trackings
    sender.contact_trackings.where(created_at: current_month...next_month)
  end

  def weekly_contact_trackings
    sender.contact_trackings.where(created_at: (Date.today - 6.days)...(Date.today + 1.day))
  end

  def daily_contact_trackings
    sender.contact_trackings.where(created_at: Date.today...(Date.today + 1.day))
  end

  def inquiries
    @sender.inquiries
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
