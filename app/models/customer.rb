require 'scraping'

class Customer < ApplicationRecord
  INDUSTRY_MAPPING = {
    'ワークリレーション' => {industry_code: 21000, company_name: "株式会社ワークリレーション", payment_date: "10日", industry_mail:"fujita@work-re.com"},
    'ワーク（外国人）' => {industry_code: 30000, company_name: "株式会社ワークリレーション", payment_date: "10日", industry_mail:"fujita@work-re.com"},
    'モンキークルー（介護）' => {industry_code: 25000, company_name: "株式会社モンキークルージャパン", payment_date: "10日", industry_mail:"takayama@monkeycrew-j.com"},
    'VIETA（介護）' => {industry_code: 26000, company_name: "株式会社VIETA GLOBAL", payment_date: "10日", industry_mail:"koji-yamada@vieta-global.com"},
    'VIETA（工場）' => {industry_code: 26000, company_name: "株式会社VIETA GLOBAL", payment_date: "10日", industry_mail:"koji-yamada@vieta-global.com"},
    'VIETA（飲食）' => {industry_code: 26000, company_name: "株式会社VIETA GLOBAL", payment_date: "10日", industry_mail:"koji-yamada@vieta-global.com"},
    'ジョイスリー（介護）' => {industry_code: 23000, company_name: "ジョイスリー株式会社", payment_date: "10日", industry_mail:"yamao.ysfm@hinode.or.jp"},
    'ニューアース（介護）' => {industry_code: 35000, company_name: "ニューアース株式会社", payment_date: "10日", industry_mail:"nshiro5_14@yahoo.co.jp"},
    '光誠会（介護）' => {industry_code: 29000, company_name: "医療法人社団光誠会", payment_date: "10日", industry_mail:"nishizawa@kouseikai-t.or.jp"},
    '登録支援機関' => {industry_code: 10000, company_name: "自社", payment_date: "", industry_mail:""},
    'エンジスト' => {industry_code: 10000, company_name: "自社", payment_date: "", industry_mail:""},
    'ワークビュー' => {industry_code: 0, company_name: "", payment_date: "", industry_mail:""},
    'ミライユ（ドライバー）' => {industry_code: 0, company_name: "", payment_date: "", industry_mail:""},
    'ミライユ（警備）' => {industry_code: 0, company_name: "", payment_date: "", industry_mail:""},
  }

  before_save :set_industry_defaults
  
  
  def industry_mail
    INDUSTRY_MAPPING[self.industry][:industry_mail]
  end

  def set_industry_defaults
    Rails.logger.debug("Setting industry defaults for #{industry}")
    defaults = INDUSTRY_MAPPING[industry]
    
    if defaults
      self.industry_code = defaults[:industry_code]
      self.company_name = defaults[:company_name]
      self.payment_date = defaults[:payment_date]
      self.industry_mail = defaults[:industry_mail]
    else
      Rails.logger.debug("No defaults found for industry: #{industry}")
    end

    Rails.logger.debug("Defaults set: #{defaults.inspect}")
  end

  def self.unique_customers_data
    # 例: industry_name をキーとし、データをグループ化して返す
    all.group_by(&:industry_name) # 適切なカラムに変更
  end
  
  def self.analytics_for(industry_name)
    customers = where(industry: industry_name)
    appointment_count = customers.count
    #unit_price_inc_tax = customers.average(:unit_price_inc_tax) || 1000 # 仮の値
    list_count = customers.where.not(created_at: nil)
    .where('customers.created_at > ?', Time.current.beginning_of_month)
    .where('customers.created_at < ?', Time.current.end_of_month)
    .to_a.count

    call_count = customers.joins(:calls)
    .where.not(calls: { created_at: nil })
    .where(calls: { statu: ["着信留守", "担当者不在", "フロントNG", "見込", "APP", "NG", "クロージングNG", "受付NG", "自己紹介NG", "質問段階NG", "日程調整NG"] })
    .where('calls.created_at > ?', Time.current.beginning_of_month)
    .where('calls.created_at < ?', Time.current.end_of_month)
    .count
    
    app_count = customers.joins(:calls)
    .where(calls: { statu: "APP" })
    .where('calls.created_at > ?', Time.current.beginning_of_month)
    .where('calls.created_at < ?', Time.current.end_of_month)
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

  def self.analytics2_for(company_name)
    customers = where(industry: company_name)
    appointment_count = customers.count
    #unit_price_inc_tax = customers.average(:unit_price_inc_tax) || 1000 # 仮の値
    list_count = customers.where.not(created_at: nil)
    .where('customers.created_at > ?', Time.current.beginning_of_month)
    .where('customers.created_at < ?', Time.current.end_of_month)
    .to_a.count

    call_count = customers.joins(:calls)
    .where.not(calls: { created_at: nil })
    .where(calls: { statu: ["着信留守", "担当者不在", "フロントNG", "見込", "APP", "NG", "クロージングNG", "受付NG", "自己紹介NG", "質問段階NG", "日程調整NG"] })
    .where('calls.created_at > ?', Time.current.beginning_of_month)
    .where('calls.created_at < ?', Time.current.end_of_month)
    .count

    app_count = customers.joins(:calls)
    .where(calls: { statu: "APP" })
    .where('calls.created_at > ?', Time.current.beginning_of_month)
    .where('calls.created_at < ?', Time.current.end_of_month)
    .to_a.count

  # app_count_customers をそのまま取得
   app_count_customers = customers.joins(:calls)
                                 .where(calls: { statu: "APP" })
                                 .where('calls.created_at > ?', Time.current.beginning_of_month)
                                 .where('calls.created_at < ?', Time.current.end_of_month)
                                 .to_a# ここで直接取得


    industry_data = INDUSTRY_MAPPING[company_name] || { industry_code: nil, company_name: nil, payment_date: nil }

    {
      company_name: company_name,
      industry_code: industry_data[:industry_code],
      company_name: industry_data[:company_name],
      payment_date: industry_data[:payment_date],
      list_count: list_count,
      call_count: call_count,
      app_count: app_count,
      app_count_customers: app_count_customers
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

  #news
  scope :between_created_at, ->(from, to){
    where(created_at: from..to).where.not(tel: nil)
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
    call_count = call_import(file)[:save_count]  # save_count で統一
    repurpose_count = repurpose_import(file)[:repurpose_import_count]  # count を統一
    draft_count = draft_import(file)[:draft_count]
    { save_count: save_count, call_count: call_count, repurpose_count: repurpose_count, draft_count: draft_count }
  end
  
  def self.import(file)
    save_count = 0
    batch_size = 2500
    batch = []
    CSV.foreach(file.path, headers: true) do |row|
      customer = find_or_initialize_by(id: row["id"])
      customer.attributes = row.to_hash.slice(*updatable_attributes)
      next if customer.industry.nil?
      next if customer.tel.blank?  # 電話番号が空の場合はスキップ
      next if where(tel: customer.tel).where(industry: nil).count > 0
      next if where(tel: customer.tel).where(industry: customer.industry).count > 0
  
      # 既にバッチに含まれていないか確認
      next if batch.any? { |c| c.tel == customer.tel && c.industry == customer.industry }
  
      customer.status = "draft"
      batch << customer
      if batch.size >= batch_size
        Customer.transaction do
          batch.each(&:save!)
        end
        save_count += batch.size
        batch.clear
      end
    end
    unless batch.empty?
      Customer.transaction do
        batch.each(&:save!)
      end
      save_count += batch.size
    end
    save_count
  end
  
  def self.call_import(call_file)
    save_cnt = 0
    batch_size = 2500
    batch = []
    
    CSV.foreach(call_file.path, headers: true) do |row|
      existing_customer = find_by(company: row['company'], industry: row['industry'])
      
      # callが存在しない顧客はスキップ
      next if existing_customer.nil? || existing_customer.calls.empty?
  
      # "再掲載" ステータスの Call が最近2ヶ月以内に登録されているかを確認
      recent_republication = existing_customer.calls.where(statu: "再掲載").where("created_at >= ?", 2.months.ago).exists?
      
      # 最新の Call を取得
      latest_call = existing_customer.calls.order(created_at: :desc).first
      
      # 再掲載が2ヶ月以内に存在しない場合か、古い Call で APP や 永久NG ではない場合にのみ追加
      if !recent_republication && (latest_call.nil? || (latest_call.created_at <= 2.months.ago && !["APP", "永久NG"].include?(latest_call.statu)))
        batch << existing_customer unless batch.include?(existing_customer)
  
        if batch.size >= batch_size
          Customer.transaction do
            batch.each do |customer|
              customer.calls.create!(statu: "再掲載", created_at: Time.current)
            end
          end
          save_cnt += batch.size
          batch.clear
        end
      end
    end
    
    # 残りのバッチがあれば処理する
    unless batch.empty?
      Customer.transaction do
        batch.each do |customer|
          customer.calls.create!(statu: "再掲載", created_at: Time.current)
        end
      end
      save_cnt += batch.size
    end
    
    { save_cnt: save_cnt }
  end
  
  def self.repurpose_import(repurpose_file)
    repurpose_import_count = 0
    batch_size = 2500
    batch = []
  
    # Crowdworkデータの取得
    crowdwork_data = Crowdwork.pluck(:title, :area).map do |title, area|
      { 'title' => title, 'area' => area.split(',') }
    end
  
    # CSVデータの処理開始
    CSV.foreach(repurpose_file.path, headers: true) do |row|
      Rails.logger.info "Processing row: #{row.to_hash}"
  
      # 既存の会社名と業界の顧客をチェック
      existing_customer = find_by(company: row['company'], industry: row['industry'])
      if existing_customer
        Rails.logger.info "Skipped existing customer: #{row['company']} - #{row['industry']}"
        next
      end
  
      # 同じ会社名の既存顧客をチェック
      existing_customer_with_same_company = find_by(company: row['company'])
      if existing_customer_with_same_company
        crowdwork = crowdwork_data.find { |cw| cw['title'] == row['industry'] }
        if crowdwork
          if existing_customer_with_same_company.address.present?
            area_match = crowdwork['area'].any? do |area|
              existing_customer_with_same_company.address.include?(area)
            end
            unless area_match
              Rails.logger.info "Skipped due to unmatched area: #{row['company']} - #{row['industry']}"
              next
            end
          else
            Rails.logger.info "Skipped due to missing address: #{row['company']}"
            next
          end
        end
  
        # repurpose_customer_attributes の作成
        repurpose_customer_attributes = row.to_hash.slice(*self.updatable_attributes).merge(
          'industry' => row['industry'],
          'url_2' => row['url_2']
        )
  
        # 新しいCustomerオブジェクトの作成
        repurpose_customer = Customer.new(
          repurpose_customer_attributes.merge(
            existing_customer_with_same_company.attributes.slice(*self.updatable_attributes).except('id').merge(
              'industry' => row['industry'],
              'url_2' => row['url_2']
            )
          )
        )
  
        # バッチに追加
        Rails.logger.info "Added to batch: #{repurpose_customer.company} - #{repurpose_customer.industry}"
        batch << repurpose_customer
  
        # バッチサイズが閾値を超えたら保存
        if batch.size >= batch_size
          Customer.transaction do
            batch.each(&:save!)
          end
          Rails.logger.info "Batch saved: #{batch.size} customers"
          repurpose_import_count += batch.size
          batch.clear
        end
      else
        Rails.logger.info "Skipped no matching company for transfer: #{row['company']}"
      end
    end
  
    # 残りのバッチを保存
    unless batch.empty?
      Customer.transaction do
        batch.each(&:save!)
      end
      Rails.logger.info "Final batch saved: #{batch.size} customers"
      repurpose_import_count += batch.size
    end
  
    Rails.logger.info "Repurpose import completed. Total saved: #{repurpose_import_count}"
    { repurpose_import_count: repurpose_import_count }
  end
    
  def self.draft_import(draft_file)
    draft_count = 0
    batch_size = 2500
    batch = []
  
    CSV.foreach(draft_file.path, headers: true) do |row|
      # 既存データの重複チェック（repurpose_import で登録されたデータも含む）
      if Customer.where(company: row['company'], industry: row['industry']).exists?
        Rails.logger.info "Skipped already imported (existing in DB): #{row['company']} - #{row['industry']}"
        next
      end
  
      # バッチ内の重複チェック
      if batch.any? { |c| c.company == row['company'] && c.industry == row['industry'] }
        Rails.logger.info "Skipped duplicate in batch: #{row['company']} - #{row['industry']}"
        next
      end
  
      # 新しい顧客を作成してバッチに追加
      customer = Customer.new(row.to_hash.slice(*updatable_attributes))
      customer.status = "draft" 
      batch << customer
  
      # バッチサイズが一定を超えた場合、一括保存
      if batch.size >= batch_size
        Customer.transaction do
          batch.each(&:save!)
        end
        Rails.logger.info "Batch saved: #{batch.size} customers"
        draft_count += batch.size
        batch.clear
      end
    end
  
    # 残りのバッチを保存
    unless batch.empty?
      Customer.transaction do
        batch.each(&:save!)
      end
      Rails.logger.info "Final batch saved: #{batch.size} customers"
      draft_count += batch.size
    end
  
    { draft_count: draft_count }
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
    # 基本のバリデーション
    unless company =~ /株式会社|有限会社|社会福祉|合同会社|医療法人|行政書士|一般社団法人|合資会社|法律事務所/
      errors.add(:company, "会社名には「株式会社」、「有限会社」、「社会福祉」、「合同会社」、「医療法人」、「行政書士」、「一般社団法人」、「合資会社」、「法律事務所」のいずれかを含める必要があります。")
    end
  
    # 店・営業所・カッコ・半角空白・全角空白を含む場合のバリデーション
    if company =~ /店|営業所|\(|\)|（|）|\s|　/
      errors.add(:company, "正しい会社名を入力してください。支店・営業所・カッコ・半角空白・全角空白は使用できません")
    end
  end
  
  def validate_tel_format
    # 半角数字とハイフンのみ、かつハイフンが含まれていないとエラー
    unless tel =~ /\A[0-9\-]+\z/ && tel.include?('-')
      errors.add(:tel, "電話番号は半角数字と「-」のみを使用し、「-」を必ず含めてください。")
    end
  
    # 数字のみ、または()が含まれていたらエラー
    if tel =~ /\A[0-9]+\z/ || tel.include?('(') || tel.include?(')')
      errors.add(:tel, "電話番号に数字のみや「( )」を使用することはできません。")
    end
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
    
    # businessとgenreが空の場合のエラー
    if business.blank?
      errors.add(:business, '未入力では登録できません')
    end
    
    if genre.blank?
      errors.add(:genre, '未入力では登録できません')
    end
    
    # businessとgenreが完全一致する場合のエラー
    if business == genre
       errors.add(:base, '業務内容を記載してください')
    end

    # Crowdworkが一致した場合の他のバリデーション
    if matching_crowdwork
      # businessのバリデーション
      if matching_crowdwork.business.present?
        unless valid_business?(matching_crowdwork.business, business)
          errors.add(:business, '指定された業種以外は登録できません。')
        end
      end
  
      # genreのバリデーション
      unless valid_genre?(matching_crowdwork.genre, genre)
        errors.add(:genre, '指定された職種が含まれていないため登録できません。')
      end
  
      # areaのバリデーション
      unless valid_area?(matching_crowdwork.area, address)
        errors.add(:address, '指定されたエリアが含まれていないため登録できません。')
      end
    end
    
    # Crowdwork.badに該当する内容が含まれている場合
    if matching_crowdwork&.bad.present?
      bad_keywords = matching_crowdwork.bad.split(',')
      if bad_keywords.any? { |keyword| business&.include?(keyword.strip) || genre&.include?(keyword.strip) }
        errors.add(:base, '抽出NGの内容が含まれています。')
      end
    end
  end
      
  def valid_business?(required_businesses, customer_business)
    # required_businessesがカンマ区切りの場合を配列に変換
    required_businesses_array = required_businesses.split(',').map(&:strip)
    # 入力されたbusinessがいずれかと一致すればtrue
    required_businesses_array.any? { |required_business| customer_business.include?(required_business) }
  end
  
  def valid_genre?(required_genre, customer_genre)
    if required_genre.blank?
      # required_genreが空の場合は無条件で通過
      true
    elsif customer_genre.present?
      # required_genreをカンマ区切りで分割して部分一致を確認
      required_genre.split(',').any? { |required| customer_genre.include?(required.strip) }
    else
      # required_genreが存在し、customer_genreが空の場合はエラー
      false
    end
  end
  
  def valid_area?(required_area, customer_address)
    # required_area がJSON形式の文字列として渡されている場合、配列に変換
    if required_area.is_a?(String) && required_area.start_with?('[')
      begin
        # 配列に変換
        required_area = JSON.parse(required_area)
      rescue JSON::ParserError
        raise "JSONのパースに失敗しました: #{required_area}"
      end
    end
  
    # 配列としての処理
    if required_area.is_a?(Array)
      # エリア内の余分な空白やクォートを除去して比較
      return required_area.any? do |area|
        cleaned_area = area.strip.gsub(/\A["']+|["']+\z/, '')  # クォートと空白を除去
        customer_address.include?(cleaned_area)
      end
    else
      # 文字列の場合の処理（配列でない場合）
      cleaned_area = required_area.strip.gsub(/\A["']+|["']+\z/, '')  # クォートと空白を除去
      return customer_address.include?(cleaned_area)
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