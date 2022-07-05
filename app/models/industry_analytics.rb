#
# 業界アナリティクス
#
# @!attribute [r] key
#   @return [String] キー
# @!attribute [r] user_id
#   @return [String, nil] ユーザ ID
# @!attribute [r] year
#   @return [Integer] 年
# @!attribute [r] month
#   @return [Integer] 月
#
class IndustryAnalytics
  include ActiveModel::Model

  attr_accessor :key, :user_id, :year, :month

  INDUSTRY_KEYS = [
    'SORAIRO（工場）',
    'SORAIRO（食品）',
    'FUJI（介護）',
    'FUJI（食品）',
    'FUJI（工場）',
    'シューマツワーカー（マーケティング）',
    'シューマツワーカー（ITエンジニア）',
    'シューマツワーカー（デザイナー）',
  ]

  class << self
    #
    # 業界分析一覧を取得する
    #
    # @param [Integer] year 年
    # @param [Integer] month 月
    # @param [String, nil] user_id ユーザ ID
    #
    # @return [Array<IndustryAnalytics>] 業界分析一覧
    #
    def industries(year, month, user_id: nil)
      INDUSTRY_KEYS.map do |industry_key|
        IndustryAnalytics.new(
          key: industry_key,
          user_id: user_id,
          year: year,
          month: month
        )
      end
    end
  end

  #
  # コール数
  #
  def call_count
    @call_count ||= summary_statuses.values.sum
  end

  #
  # 着信留守数
  #
  def incomming_absence_count
    summary_status_count('着信留守')
  end

  #
  # 担当者不在数
  #
  def manager_absence_count
    summary_status_count('担当者不在')
  end

  #
  # 見込数
  #
  def expected_count
    summary_status_count('見込')
  end

  #
  # アポ数
  #
  def appointment_count
    summary_status_count('APP')
  end

  #
  # キャンセル数
  #
  def cancel_count
    summary_status_count('APPキャンセル')
  end

  #
  # NG数
  #
  def ng_count
    summary_status_count('NG')
  end

  #
  # フロントNG数
  #
  def front_ng_count
    summary_status_count('フロントNG')
  end

  #
  # クロージングNG数
  #
  def closing_ng_count
    summary_status_count('クロージングNG')
  end

  #
  # 永久NG数
  #
  def forever_ng_count
    summary_status_count('永久NG')
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
    incentive.value || sales_unit # 売り上げと単価同じかどうか
  end

  #
  # 残数
  #
  def remain_count
    max_count = key == 'SORAIRO' ? 30 : 10

    return 0 if appointment_count > max_count

    appointment_count - appointment_count
  end

  #
  # インセンティブを更新する
  #
  def incentive_attributes=(new_incentive)
    incentive.value = new_incentive[:value]
  end

  def save_incentive
    if incentive.value
      incentive.save!
    elsif !incentive.new_record?
      incentive.destroy
    end
  end

  private

  #
  # コール一覧
  #
  def calls
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

    calls
  end

  def summary_statuses
    @summary_statuses ||= calls.group(:statu).count(:id)
  end

  def summary_status_count(status)
    summary_statuses[status] || 0
  end

  def sales_unit
    return 29000 if key == 'SORAIRO'
    return 24750 if key == 'サンズ'
    return 26950 if key == 'lapi（介護）'
    return 26950 if key == 'lapi（コール）'
    return 26950 if key == 'lapi（工場）'


    33000
  end

  def incentive
    @incentive ||= Incentive.find_or_initialize_by(
      customer_summary_key: key,
      year: year,
      month: month
    )
  end
end
