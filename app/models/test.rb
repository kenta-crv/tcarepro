class Test < ApplicationRecord
  belongs_to :worker

  validate :validate_company_format, if: -> { !new_record? }
  validate :validate_tel_format, if: -> { !new_record? }
  validate :validate_address_format, if: -> { !new_record? }
  validate :validate_crowdwork_business, if: -> { !new_record? }
  validate :validate_crowdwork_genre, if: -> { !new_record? }

  def validate_crowdwork_business
    allowed_business = ["介護", "工場", "販売"]
    if genre.present? && !allowed_business.include?(business)
      errors.add(:business, "指定職種が含まれていません。")
    end
  end

  def validate_crowdwork_genre
    allowed_genres = ["老人ホーム", "金属加工", "レディースファッション"]
    matching_genre = allowed_genres.find { |g| genre.to_s.include?(g) }
    if genre.present? && !matching_genre
      errors.add(:genre, "指定された職種が含まれていません。許可されている職種は #{allowed_genres.join(', ')} です。")
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
end
