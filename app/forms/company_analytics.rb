#
# 企業アナリティクス
#
# @!attribute [r] name
#   @return [String] 企業名
# @!attribute [r] coefficient
#   @return [Integer] 係数
#
class CompanyAnalytics
  attr_reader :name

  def initialize(name, coefficient)
    @name = name
    @coefficient = coefficient
  end

  #
  # コール数
  #
  def count
    unless @count
      calls = Call
        .joins(:customer)
        .select('calls.id')
        .where(created_at: Time.current.beginning_of_month..Time.current.end_of_month)

      if name == 'SORAIRO'
        calls.where!("industry LIKE ?", "%#{name}%")
      else
        calls.where!("industry LIKE ?", "%#{name}")
      end

      @count = calls.count
    end
    @count
  end

  #
  # アポ数
  #
  def appointment_count
    @appointment_count ||= Customer2
      .joins(:calls)
      .select('calls.id')
      .where("industry LIKE ?", "%#{name}%")
      .where(calls: { statu: 'APP' })
      .where("calls.created_at > ?", Time.current.beginning_of_month).where("calls.created_at < ?", Time.current.end_of_month)
      .count
  end

  #
  # コールアポ率
  #
  def appointment_rate
    return 0 if count <= 0

    appointment_count * 100.0 / count
  end

  #
  # 売り上げ
  #
  def sales
    appointment_count * coefficient
  end

  #
  # インセンティブ合計
  #
  def incentives
    return 0 if name == 'SORAIRO'
  
    appointment_count * coefficient
  end

  #
  # 残数
  #
  def remain_count
    max_count = name == 'SORAIRO' ? 30 : 10

    return 0 if appointment_count > max_count

    appointment_count - appointment_count
  end

  private

  attr_reader :coefficient
end
