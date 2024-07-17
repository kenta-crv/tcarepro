class Test < ApplicationRecord
  attr_accessor :skip_validation
  belongs_to :worker

  validate :validate_company_format, unless: :skip_validation?
  validate :validate_tel_format, unless: :skip_validation?
  validate :validate_address_format, unless: :skip_validation?
  validate :validate_crowdwork_business, unless: :skip_validation?
  validate :validate_crowdwork_genre, unless: :skip_validation?

  def validate_crowdwork_business
    unless business =~ /介護|工場|販売/
      errors.add(:business, "指定された業種が記載されていません。また空白では登録できません。")
    end
  end

  def validate_crowdwork_genre
    unless genre =~ /老人ホーム|金属加工|レディースファッション/
      errors.add(:genre, "指定された職種が記載されていません。また空白では登録できません。")
    end
  end

  def validate_company_format
    unless company =~ /株式会社|有限会社|社会福祉|合同会社|医療法人/
      errors.add(:company, "会社名には「株式会社」、「有限会社」、「社会福祉」、「合同会社」、「医療法人」のいずれかを含める必要があります。")
    end

    if company =~ /支店|営業所/
      errors.add(:company, "会社名には「支店」と「営業所」を含むことはできません。")
    end
  end

  def validate_tel_format
    errors.add(:tel, "電話番号には「0」と「-」以外の文字を含めることはできません") if tel =~ /[^0\-]/
    errors.add(:tel, "電話番号には「0120」と「0088」を含むことはできません") if tel !~ /\A[0-9\-]+\z/ || tel =~ /0120|0088/
  end

  def validate_address_format
    unless address =~ /都|道|府|県/
      errors.add(:address, "住所には都・道・府・県のいずれかを含める必要があります")
    end
  end
  private

  def skip_validation?
    skip_validation == true
  end
end
