require 'scraping'

class Customer < ApplicationRecord
  INDUSTRY_MAPPING = {
    'コンシェルテック（営業）' => {industry_code: 15000, company_name: "株式会社コンシェルテック", payment_date: "末日"},
    'コンシェルテック（販売）' => {industry_code: 15000, company_name: "株式会社コンシェルテック", payment_date: "末日"},
    'コンシェルテック（工場）' => {industry_code: 15000, company_name: "株式会社コンシェルテック", payment_date: "末日"},
    'SORAIRO（工場）' => {industry_code: 27273, company_name: "株式会社未来ジャパン", payment_date: "末日"},
    'SORAIRO（食品）' => {industry_code: 27273, company_name: "株式会社未来ジャパン", payment_date: "末日"},
    'SOUND（介護）' => {industry_code: 27500, company_name: "一般社団法人日本料飲外国人雇用協会", payment_date: "末日"},
    'SOUND（食品）' => {industry_code: 27500, company_name: "一般社団法人日本料飲外国人雇用協会", payment_date: "末日"},
    'グローバルイノベーション' => {industry_code: 30000, company_name: "協同組合グローバルイノベーション", payment_date: "10日"},
    'ニュートラル（介護）' => {industry_code: 25000, company_name: "ニュートラル協同組合", payment_date: "10日"},
    'グローバル（食品）' => {industry_code: 30000, company_name: "グローバル協同組合", payment_date: "10日"},
    'グローバル（介護）' => {industry_code: 30000, company_name: "グローバル協同組合", payment_date: "10日"},
    'ワークリレーション' => {industry_code: 15000, company_name: "株式会社ワークリレーション", payment_date: "10日"},
    'ワーク（工場）' => {industry_code: 15000, company_name: "株式会社ワークリレーション", payment_date: "10日"},
    'データ入力' => {industry_code: 15000, company_name: "株式会社セールスプロ", payment_date: "10日"},
    '富士（工場）' => {industry_code: 29000, company_name: "株式会社さこんじ", payment_date: "10日"}, 
    '富士（飲食）' => {industry_code: 29000, company_name: "株式会社さこんじ", payment_date: "10日"},
    'モンキージャパン（介護）' => {industry_code: 25000, company_name: "株式会社モンキークルージャパン", payment_date: "10日"},
    'VIETA（介護）' => {industry_code: 26000, company_name: "株式会社VIETA GLOBAL", payment_date: "10日"},
    'VIETA（工場）' => {industry_code: 26000, company_name: "株式会社VIETA GLOBAL", payment_date: "10日"},
    'VIETA（飲食）' => {industry_code: 26000, company_name: "株式会社VIETA GLOBAL", payment_date: "10日"},
    'ジョイスリー（介護）' => {industry_code: 23000, company_name: "ジョイスリー株式会社", payment_date: "10日"},
  }

  before_save :set_industry_defaults

  def set_industry_defaults
    Rails.logger.debug("Setting industry defaults for #{industry}")
    defaults = INDUSTRY_MAPPING[industry]
    
    if defaults
      self.industry_code = defaults[:industry_code]
      self.company_name = defaults[:company_name]
      self.payment_date = defaults[:payment_date]
    else
      Rails.logger.debug("No defaults found for industry: #{industry}")
    end

    Rails.logger.debug("Defaults set: #{defaults.inspect}")
  end
  
  def set_industry_defaults
    return unless INDUSTRY_MAPPING.key?(industry)

    defaults = INDUSTRY_MAPPING[industry]
    self.industry_code = defaults[:industry_code]
    self.company_name = defaults[:company_name]
    self.payment_date = defaults[:payment_date]
  end

  def self.analytics_for(industry_name)
    customers = where(industry: industry_name)
    appointment_count = customers.count
    #unit_price_inc_tax = customers.average(:unit_price_inc_tax) || 1000 # 仮の値
    list_count = customers.where.not(created_at: nil)
    .where('customers.created_at > ?', Time.current.beginning_of_day)
    .where('customers.created_at < ?', Time.current.end_of_day)
    .to_a.count

    call_count = customers.joins(:calls)
    .where.not(calls: { created_at: nil })
    .where('calls.created_at > ?', Time.current.beginning_of_day)
    .where('calls.created_at < ?', Time.current.end_of_day)
    .count

    app_count = customers.joins(:calls)
    .where(calls: { statu: "APP" })
    .where('calls.created_at > ?', Time.current.beginning_of_day)
    .where('calls.created_at < ?', Time.current.end_of_day)
    .to_a.count
    # 業界情報を取得
    industry_data = INDUSTRY_MAPPING[industry_name] || { industry_code: nil, company_name: nil, payment_date: nil }

    {
      industry_name: industry_name,
      industry_code: industry_data[:industry_code],
      company_name: industry_data[:company_name],
      payment_date: industry_data[:payment_date],
      list_count: list_count,
      call_count: call_count,
      app_count: app_count,
    }
  end


  before_save :set_industry_defaults
  belongs_to :user, optional: true
  belongs_to :worker, optional: true
  has_many :estimates
  has_many :calls#, foreign_key: :tel, primary_key: :tel
  has_many :counts
  has_one :last_call, ->{
    order("created_at desc")
  }, class_name: :Call
  has_many :contact_trackings
  has_one :contact_tracking, ->{
    eager_load(:contact_trackings).order(sended_at: :desc)
  }

  has_one :last_contact, ->{
    order("created_at desc")
  }, class_name: 'ContactTracking'

  scope :last_contact_trackings, ->(sender_id, status){
    joins(:contact_trackings).where(contact_trackings: { id: ContactTracking.latest(sender_id).select(:id), status: status })
  }

  scope :last_contact_trackings_only, ->(sender_id){
    joins(:contact_trackings).where(contact_trackings: { id: ContactTracking.latest(sender_id).select(:id) })
  }

  has_one :latest_contact_tracking, -> { order(sended_at: :desc) }, class_name: 'ContactTracking'

  scope :with_latest_contact_tracking, -> {
    joins(:latest_contact_tracking).where('contact_trackings.id IS NOT NULL')
  }

  # Direct Mail Contact Trackings
  #has_many :direct_mail_contact_trackings
  #has_one :direct_mail_contact_tracking, ->{
  #  eager_load(:direct_mail_contact_trackings).order(sended_at: :desc)
  #}


  scope :with_is_contact_tracking, -> is_contact_tracking {
    if is_contact_tracking == "true"
      contact_trackings.exists?
    end
  }


  scope :between_created_at, ->(from, to){
    where(created_at: from..to)
  }

  scope :between_nexted_at, ->(from, to){
    joins(:calls).where("calls.created_at": from..to).where("calls.statu": "再掲載")
  }

  scope :between_called_at, ->(from, to){
    where(created_at: from..to)
  }

  scope :between_updated_at, ->(from, to){
    where(updated_at: from..to).where.not(tel: nil)
  }


  scope :ltec_calls_count, ->(count){
    filter_ids = joins(:calls).group("calls.customer_id").having('count(*) <= ?',count).count.keys
    where(id: filter_ids)
  }

scope :before_sended_at, ->(sended_at){
  eager_load(:contact_trackings).merge(ContactTracking.before_sended_at(sended_at))
}

  scope :with_company, -> company {
    if company.present?
      where("company LIKE ?", "%#{company}%")
    end
  }

  scope :with_tel, -> tel {
    if tel.present?
      where("tel LIKE ?", "%#{tel}%")
    end
  }

  scope :with_address, -> address {
    if address.present?
      where(address: address)
    end
  }

  scope :with_status, ->(statuses) {
    if statuses.present?
      where(status: statuses)
    end
  }

  scope :with_business, -> business {
    if business.present?
      where("business LIKE ?", "%#{business}%")
    end
  }

  scope :with_genre, -> genre {
    if genre.present?
      where("genre LIKE ?", "%#{genre}%")
    end
  }

  scope :with_choice, -> choice {
    if choice.present?
      where("choice LIKE ?", "%#{choice}%")
    end
  }

  scope :with_industry, -> industry {
    if industry.present?
      where("industry LIKE ?", "%#{industry}%")
    end
  }

  scope :with_created_at, -> (from, to) {
    from_date_time = Time.zone.parse(from).beginning_of_day if from.present?
    to_date_time = Time.zone.parse(to).end_of_day if to.present?

    if from_date_time.present? && to_date_time.present?
      where(created_at: from_date_time..to_date_time)
    elsif from_date_time.present?
      where('created_at >= ?', from_date_time)
    elsif to_date_time.present?
      where('created_at <= ?', to_date_time)
    end
  }

  scope :with_contact_tracking_sended_at, ->(from, to) {
    where(contact_tracking_sended_at: (from.beginning_of_day..to.end_of_day))
  }

  def self.updatable_attributes
    ["id", "company", "store", "tel", "address", "url", "url_2", "title", "industry", "mail", "first_name", "postnumber", "people",
     "caption", "business", "genre", "mobile", "choice", "inflow", "other", "history", "area", "target", "meeting", "experience", "price",
     "number", "start", "remarks", "extraction_count", "send_count"]
  end

  def self.call_attributes
    ["customer_id" ,"statu", "time", "comment", "created_at","updated_at"]
  end

  def self.all_import(file)
    save_count = import(file)
    call_count = call_import(file)
    repurpose_count = repurpose_import(file)
    
    { save_count: save_count, call_count: call_count, repurpose_count: repurpose_count }
  end
  
  # 既存の import メソッド
  def self.import(file)
    save_cont = 0
    CSV.foreach(file.path, headers:true) do |row|
      customer = find_by(id: row["id"]) || new
      customer.attributes = row.to_hash.slice(*updatable_attributes)
      next if customer.industry.nil?
      next if where(tel: customer.tel).where(industry: nil).count > 0
      next if where(tel: customer.tel).where(industry: customer.industry).count > 0
      customer.save!
      save_cont += 1
    end
    save_cont
  end

  def self.call_import(call_file)
    save_cnt = 0
    CSV.foreach(call_file.path, headers: true) do |row|
      # companyとindustryが一致する既存のCustomerを探す
      existing_customer = find_by(company: row['company'], industry: row['industry'])
      if existing_customer
        # industryが一致する場合、再掲載処理を行う
        latest_call = existing_customer.calls.order(created_at: :desc).first
        # 最新のcallが存在し、2ヶ月以上経過していて、かつstatuが"APP"または"永久NG"でない場合のみ再掲載
        if latest_call && latest_call.created_at <= 2.months.ago && !["APP", "永久NG"].include?(latest_call.statu)
          existing_customer.calls.create!(statu: "再掲載", created_at: Time.current)
          save_cnt += 1
        end
      end
    end
    { save_cnt: save_cnt }  # 修正：ハッシュを返す
  end

  def self.repurpose_import(repurpose_file)
    repurpose_import_count = 0
    CSV.foreach(repurpose_file.path, headers: true) do |row|
      # インポートデータの company と industry が一致する既存データを検索
      existing_customer = find_by(company: row['company'], industry: row['industry'])
      if existing_customer
        # 条件1: industry と company が一致する既存データが存在する場合、登録をスキップ
        next
      else
        # 条件2: company が一致し、industry が異なる場合
        existing_customer_with_same_company = find_by(company: row['company'])
        if existing_customer_with_same_company
          # 既存データの電話番号が存在するか確認
          next if existing_customer_with_same_company.tel.blank?
          # 新規Customerのデータを作成
          repurpose_customer_attributes = row.to_hash.slice(*self.updatable_attributes).tap do |attributes|
            attributes['industry'] = row['industry']
            attributes['url_2'] = row['url_2']
          end
          # 既存データの属性を転用し、新しいCustomerを作成
          repurpose_customer = Customer.new(repurpose_customer_attributes.merge(
            existing_customer_with_same_company.attributes.slice(*self.updatable_attributes).except('id').merge(
              'industry' => row['industry'],
              'url_2' => row['url_2']
            )
          ))
          repurpose_customer.save!
          repurpose_import_count += 1
        end
      end
    end
    { repurpose_import_count: repurpose_import_count }  # 修正：ハッシュを返す
  end  

  def self.draft_import(draft_file)
    draft_import_count = 0  # 保存された顧客の数をカウントするための変数
    CSV.foreach(draft_file.path, headers: true) do |row|
      # 電話番号 (tel) が空でない場合はスキップ
      next if row['tel'].present?
      # company と industry、または store と industry の組み合わせで既存データを検索
      existing_customer = find_by(industry: row['industry'], company: row['company']) ||
                          find_by(industry: row['industry'], store: row['store'])
      # 条件に一致する既存顧客が存在する場合はスキップ
      next if existing_customer
      # 新規Customerのデータを作成
      customer = Customer.new(row.to_hash.slice(*updatable_attributes))
      # industry が存在しない場合はスキップ
      next if customer.industry.nil?
      # status を "draft" に設定
      customer.status = "draft"
      # バリデーションをスキップ
      customer.skip_validation = true
      draft_import_count += 1
    end
    { draft_import_count: draft_import_count }
  end
  
  #customer_export
  def self.generate_csv
    CSV.generate(headers:true) do |csv|
      csv << csv_attributes
      all.each do |task|
        csv << csv_attributes.map{|attr| task.send(attr)}
      end
    end
  end
  def self.csv_attributes
    ["id","company","store","tel","address","url","url_2","title","industry","mail","first_name","postnumber","people",
     "caption","business","genre","mobile","choice","inflow","other","history","area","target","meeting","experience","price",
     "number","start","remarks","extraction_count","send_count"]
  end

  def self.ransackable_scopes(_auth_object = nil)
    [:calls_count_lt]
  end

  def self.calls_count_lt(count)
    select('*, COUNT(calls.id) AS calls_count')
    .joins(:calls)
    .group('customers.id')
    .where('calls_count <= ?', count)
  end

  @@business_status2 = [
    ["人材関連業","人材関連業"],
    ["協同組合","協同組合"],
    ["登録支援機関","登録支援機関"],
    ["IT・エンジニア","IT・エンジニア"],
    ["ホームページ制作","ホームページ制作"],
    ["Webデザイナー","Webデザイナー"],
    ["食品加工業","食品加工業"],
    ["製造業","製造業"],
    ["広告業","広告業"],
    ["営業","営業"],
    ["販売","販売"],
    ["介護","介護"],
    ["マーケティング業","マーケティング業"],
    ["コンサルティング業","コンサルティング業"],
    ["不動産","不動産"],
    ["商社","商社"],
    ["ドライバー","ドライバー"],
    ["運送業","運送業"],
    ["タクシー","タクシー"],
    ["建設土木業","建設土木業"],
    ["自動車整備工場","自動車整備工場"],
    ["教育業","教育業"],
    ["飲食業","飲食業"],
    ["美容院","美容院"],
    ["看護・病院","看護・病院"],
    ["弁護士","弁護士"],
    ["社会保険労務士","社会保険労務士"],
    ["保育士","保育士"],
    ["旅行業","旅行業"],
    ["警備業","警備業"],
    ["その他","その他"],
  ]
  def self.BusinessStatus2
    @@business_status2
  end

  @@business_status = [
    ["人材関連業","人材関連業"],
    ["広告業","広告業"],
    ["マーケ・コンサルティング業","マーケ・コンサルティング業"],
    ["飲食店","飲食店"],
    ["美容業","美容業"],
    ["製造業","製造業"],
    ["IT・エンジニア・Web制作","IT・エンジニア・Web制作"],
    ["建設土木業","建設土木業"],
    ["製造業","製造業"],
    ["福祉・医療","福祉・医療"],
    ["商社","商社"],
    ["教育業","教育業"],
    ["専門サービス業","専門サービス業"],
    ["その他","その他"]
  ]
  def self.BusinessStatus
    @@business_status
  end

  @@send_status = [
    ["メール送信済","メール送信済"]
  ]
  def self.SendStatus
    @@send_status
  end

  

  def get_search_url
    unless @contact_url
      @contact_url =
        scraping.contact_from(url_2) ||
        scraping.contact_from(url) ||
        scraping.contact_from(
          scraping.google_search([company, address, tel].compact.join(' '))
        )
    end
    @contact_url
  end

  def google_search_url
    scraping.google_search([company, address, tel].compact.join(' '))
  end

  def get_url_arry
    url_arry = []
    url_arry.push(url) if url.present?
    url_arry.push(url_2) if url_2.present?

    url_arry
  end


  #APPをカウントカウント
  def total_industry_code_for_app_calls
    calls.where(statu: 'APP').joins(:customer).sum('customers.industry_code')
  end

  def industry_name
    INDUSTRY_MAPPING.each do |key, value|
      return key if value[:company_name] == self.company_name
    end
    nil
  end

  def payment_date
    INDUSTRY_MAPPING.each do |key, value|
      return value[:payment_date] if value[:company_name] == self.company_name
    end
    nil
  end

  attr_accessor :skip_validation

  validate :validate_company_format, if: -> { !new_record? && !skip_validation }
  validate :validate_tel_format, if: -> { !new_record? && !skip_validation }
  validate :validate_address_format, if: -> { !new_record? && !skip_validation }
  validate :industry_matches_crowdwork_title_and_validate_business_and_genre, if: -> { !new_record? && !skip_validation }
  validate :unique_industry_and_tel_or_company_for_same_worker, if: -> { !new_record? && !skip_validation }
  
  # その他のコード
  
  private
  
  def unique_industry_and_tel_or_company_for_same_worker
    existing_customer = Customer.where(worker_id: worker_id)
                                .where(industry: industry)
                                .where("tel = ? OR company = ?", tel, company)
  
    if existing_customer.exists?
      errors.add(:base, "過去に同一電話番号または会社名を登録しています。同一ワーカーでの重複登録はできません。")
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
    errors.add(:tel, "電話番号には「半角数字」と「-」以外の文字を含めることはできません。いずれも該当しない場合、半角空白や全角空白が含まれている場合があります。") if tel !~ /\A[0-9\-]+\z/
    errors.add(:tel, "電話番号には「0120」と「0088」を含むことはできません。いずれも該当しない場合、半角空白や全角空白が含まれている場合があります。") if tel !~ /\A[0-9\-]+\z/ || tel =~ /0120|0088/
  end
  
  def validate_address_format
    unless address =~ /都|道|府|県/
      errors.add(:address, "住所には都・道・府・県のいずれかを含める必要があります")
    end
  end
  
  def set_industry_code
    self.industry_code = INDUSTRY_MAPPING[self.industry]
  end
  
  def industry_matches_crowdwork_title_and_validate_business_and_genre
    # CustomerのindustryがCrowdworkのtitleと一致するかをチェック
    matching_crowdwork = Crowdwork.find_by(title: industry)
    if matching_crowdwork
      # businessのバリデーションを行う
      unless valid_business?(matching_crowdwork.business, business)
        errors.add(:business, '指定された業種以外は登録できません。')
      end 
      # genreのバリデーションを行う
      unless valid_genre?(matching_crowdwork.genre, genre)
        errors.add(:genre, '指定された職種が含まれていないため登録できません。')
      end
      # areaのバリデーションを行う
      unless valid_area?(matching_crowdwork.area, address)
        errors.add(:address, '指定されたエリアが含まれていないため登録できません。')
      end
    end
  end
  
  def valid_business?(required_business, customer_business)
    # 2文字以上一致する場合にバリデーション通過
    required_business.present? && customer_business.present? && (required_business & customer_business).size >= 2
  end
  
  def valid_genre?(required_genre, customer_genre)
    # 部分一致を求めるgenreのバリデーションロジック
    customer_genre.include?(required_genre)
  end
  
  def valid_area?(required_area, customer_address)
    # required_area が配列の場合
    if required_area.is_a?(Array)
      # 配列内のいずれかのエリアが customer_address に含まれているかをチェック
      required_area.any? { |area| customer_address.include?(area.to_s) }
    else
      # required_area が文字列の場合
      customer_address.include?(required_area.to_s)
    end
  end
  
  #draftでworkerの履歴を残す
  def add_worker_update_history(worker, status)
    self.update_history = {} if self.update_history.nil?
    self.update_history[worker.id] = { status: status, updated_at: Time.current }
    save
  end

  def scraping
    @scraping ||= Scraping.new
  end
  
end