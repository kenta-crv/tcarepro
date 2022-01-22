class ClientsForm
  include ActiveModel::Model

  attr_accessor :industry, :year, :month, :day

  delegate :incomming_absence_count,
    :manager_absence_count,
    :expected_count,
    :appointment_count,
    :cancel_count,
    :ng_count,
    :appointment_rate,
    to: :industry_analytics

  def initialize(attributes)
    super(attributes)
    self.year ||= Time.zone.now.year
    self.month ||= Time.zone.now.month
    self.day ||= Time.zone.now.day
  end

  #
  # 本日のコール一覧
  #
  def today_calls
    Call
      .joins(:customer)
      .preload(:customer)
      .where(customers: { industry: industry })
      .where(created_at: current_time.beginning_of_day..current_time.end_of_day)
  end

  #
  # 着信留守率
  #
  def incomming_absence_rate
    return 0 if industry_analytics.call_count == 0

    incomming_absence_count * 100.0 / industry_analytics.call_count
  end

  #
  # 担当者不在率
  #
  def manager_absence_rate
    return 0 if industry_analytics.call_count == 0

    manager_absence_count * 100.0 / industry_analytics.call_count
  end

  #
  # 見込率
  #
  def expected_rate
    return 0 if industry_analytics.call_count == 0

    expected_count * 100.0 / industry_analytics.call_count
  end

  #
  # アポ率
  #
  def appointment_rate
    return 0 if industry_analytics.call_count == 0

    appointment_count * 100.0 / industry_analytics.call_count
  end

  #
  # キャンセル率
  #
  def cancel_rate
    return 0 if industry_analytics.call_count == 0

    cancel_count * 100.0 / industry_analytics.call_count
  end

  #
  # NG率
  #
  def ng_rate
    return 0 if industry_analytics.call_count == 0

    ng_count * 100.0 / industry_analytics.call_count
  end

  #
  # 前の日のクエリ
  #
  def prev_day_query
    prev_time = current_time - 1.day

    {
      clients_form: {
        year: prev_time.year,
        month: prev_time.month,
        day: prev_time.day,
      },
    }
  end

  #
  # 次の日のクエリ
  #
  def next_day_query
    next_time = current_time + 1.day

    {
      clients_form: {
        year: next_time.year,
        month: next_time.month,
        day: next_time.day,
      },
    }
  end

  def current_time
    Time.local(year, month, day)
  end

  private

  def industry_analytics
    @industry_analytics = Rails.cache.fetch(
      "/client/#{industry}/#{year}/#{month}",
      expires_in: 1.minute
    ) do
      IndustryAnalytics.new(
        key: industry,
        year: year,
        month: month
      )
    end
  end
end
