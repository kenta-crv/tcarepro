class InformationAnalyticForm
  include ActiveModel::Model

  attr_accessor :user_id, :year, :month

  def call_count
    industries.sum(&:call_count)
  end

  def appointment_rate
    return 0 if call_count <= 0

    appointment_count * 100.0 / call_count
  end

  def appointment_count
    industries.sum(&:appointment_count)
  end

  def sales
    industries.sum(&:sales)
  end

  def incentive_total
    industries.sum(&:incentive_total)
  end

  def industries
    @industries ||= IndustryAnalytics.industries(year, month, user_id: user_id)
  end

  def users
    @users ||= User.all
  end

  def selected_user
    return nil unless user_id

    @selected_user ||= User.find(user_id)
  end

  def link_to_queries(key = nil)
    next_month = Date.new(year.to_i, month.to_i, 1) + 1.month

    queries = {
      last_call: {
        created_at_from: "#{year}-#{'%02d' % month}-01",
        created_at_to: "#{next_month.year}-#{'%02d' % next_month.month}-01",
        statu: 'APP',
      },
      q: {},
    }

    queries[:q][:industry_cont] = key if key

    queries[:q][:calls_user_user_name_cont] = selected_user.user_name if selected_user

    queries
  end
end
