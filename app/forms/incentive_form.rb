class IncentiveForm
  include ActiveModel::Model

  attr_accessor :year, :month

  def appointment_count
    @appointment_count ||= industries.sum(&:appointment_count)
  end

  def incentive_total
    industries.sum(&:incentive_total)
  end

  def industries
    @industries ||= IndustryAnalytics.industries(year, month)
  end

  def industries=(new_industries)
    new_industries.each do |new_industry|
      new_incentive = new_industry[:incentive]
      industry = industries.find do |industry|
        industry.key ==  new_incentive[:customer_summary_key]
      end

      industry.incentive_attributes = new_incentive
    end
  end

  def save!
    industries.each(&:save_incentive)
  end
end
