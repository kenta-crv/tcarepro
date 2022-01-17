#
# 業界アナリティクス
#
# @!attribute [r] key
#   @return [String] キー
# @!attribute [r] user_id
#   @return [String] ユーザ ID
# @!attribute [r] year
#   @return [Integer] 年
# @!attribute [r] month
#   @return [Integer] 月
#
class IndustryAnalytics
  include ActiveModel::Model

  attr_accessor :key, :user_id, :year, :month

  #
  # コール数
  #
  def call_count
    @call_count ||= calc_count
  end

  #
  # アポ数
  #
  def appointment_count
    @appointment_count ||= calc_count { |calls| calls.where(statu: 'APP') }
  end

  #
  # コールアポ率
  #
  def appointment_rate
    return 0 if call_count <= 0

    appointment_count * 100.0 / call_count
  end

  #
  # 売り上げ
  #
  def sales
    sales_unit * appointment_count
  end

  #
  # インセンティブ合計
  #
  def incentive_total
    incentive_unit * appointment_count
  end

  #
  # インセンティブ単価
  #
  def incentive_unit
    incentive&.value || sales_unit # 売り上げと単価同じかどうか
  end

  #
  # 残数
  #
  def remain_count
    max_count = key == 'SORAIRO' ? 30 : 10

    return 0 if appointment_count > max_count

    appointment_count - appointment_count
  end

  private

  def sales_unit
    return 29000 if key == 'SORAIRO'
    return 24750 if key == 'サンズ'

    33000
  end

  def calc_count(&block)
    current_time = Time.local(year, month)

    calls = Call
      .joins(:customer)
      .where(created_at: current_time.beginning_of_month..current_time.end_of_month)

    if key == 'SORAIRO'
      # SORAIRO のみ過去にキーが変更となっているため部分一致で検索する
      calls = calls.where("industry LIKE ?", "%#{key}%")
    else
      calls = calls.where(customers: { industry: key })
    end

    calls = calls.where(user_id: user_id) if user_id

    calls = block.call(calls) if block

    calls.count
  end

  def incentive
    @incentive ||= Incentive.find_or_initialize_by(
      customer_summary_key: key,
      year: year,
      month: month
    )
  end
end
