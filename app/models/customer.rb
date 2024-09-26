require 'scraping'

class Customer < ApplicationRecord
  INDUSTRY_MAPPING = {
    'コンシェルテック（営業）' => {industry_code: 15000, company_name: "株式会社コンシェルテック", payment_date: "末日"},
    'コンシェルテック（販売）' => {industry_code: 15000, company_name: "株式会社コンシェルテック", payment_date: "末日"},
    'コンシェルテック（工場）' => {industry_code: 15000, company_name: "株式会社コンシェルテック", payment_date: "末日"},
    'SORAIRO（工場）' => {industry_code: 27273, company_name: "株式会社未来ジャパン", payment_date: "末日"},
    'SOUND（介護）' => {industry_code: 27500, company_name: "一般社団法人日本料飲外国人雇用協会", payment_date: "末日"},
    'SOUND（食品）' => {industry_code: 27500, company_name: "一般社団法人日本料飲外国人雇用協会", payment_date: "末日"},
    'グローバルイノベーション' => {industry_code: 30000, company_name: "協同組合グローバルイノベーション", payment_date: "10日"},
    'グローバル（介護）' => {industry_code: 30000, company_name: "グローバル協同組合", payment_date: "10日"},
    'ワークリレーション' => {industry_code: 21000, company_name: "株式会社ワークリレーション", payment_date: "10日"},
    'ワーク（外国人）' => {industry_code: 30000, company_name: "株式会社ワークリレーション", payment_date: "10日"},
    'モンキージャパン（介護）' => {industry_code: 25000, company_name: "株式会社モンキークルージャパン", payment_date: "10日"},
    'VIETA（介護）' => {industry_code: 26000, company_name: "株式会社VIETA GLOBAL", payment_date: "10日"},
    'VIETA（工場）' => {industry_code: 26000, company_name: "株式会社VIETA GLOBAL", payment_date: "10日"},
    'VIETA（飲食）' => {industry_code: 26000, company_name: "株式会社VIETA GLOBAL", payment_date: "10日"},
    'ジョイスリー（介護）' => {industry_code: 23000, company_name: "ジョイスリー株式会社", payment_date: "10日"},
    'ニューアース' => {industry_code: 35000, company_name: "ニューアース株式会社", payment_date: "10日"},
    '光誠会' => {industry_code: 29000, company_name: "医療法人社団光誠会", payment_date: "10日"},
    '登録支援機関' => {industry_code: 10000, company_name: "自社", payment_date: ""},
    'エンジスト' => {industry_code: 10000, company_name: "自社", payment_date: ""},
    'ケアリンク' => {industry_code: 10000, company_name: "自社", payment_date: ""},
    'エクステリア' => {industry_code: 10000, company_name: "自社", payment_date: ""},
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
    .where('customers.created_at > ?', Time.current.beginning_of_month)
    .where('customers.created_at < ?', Time.current.end_of_month)
    .to_a.count

    call_count = customers.joins(:calls)
    .where.not(calls: { created_at: nil })
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
      if existing_customer
        # 既に "再掲載" ステータスの Call が最近2ヶ月以内に登録されているかを確認
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
    
    crowdwork_data = Crowdwork.pluck(:title, :area).map do |title, area|
      { 'title' => title, 'area' => area.split(',') }
    end
    
    CSV.foreach(repurpose_file.path, headers: true) do |row|
      existing_customer = find_by(company: row['company'], industry: row['industry'])
      
      if existing_customer
        next
      else
        existing_customer_with_same_company = find_by(company: row['company'])
        
        if existing_customer_with_same_company
          crowdwork = crowdwork_data.find { |cw| cw['title'] == row['industry'] }
          
          if crowdwork
            if existing_customer_with_same_company.address.present?
              area_match = crowdwork['area'].any? do |area|
                existing_customer_with_same_company.address.include?(area)
              end
              next unless area_match
            else
              next
            end
          end
  
          # 既にバッチに含まれていないか確認
          next if batch.any? { |c| c.company == row['company'] && c.industry == row['industry'] }
  
          # repurpose_customer_attributes の作成
          repurpose_customer_attributes = row.to_hash.slice(*self.updatable_attributes).merge(
            'industry' => row['industry'],
            'url_2' => row['url_2']
          )
  
          # Customer オブジェクトを作成
          repurpose_customer = Customer.new(
            repurpose_customer_attributes.merge(
              existing_customer_with_same_company.attributes.slice(*self.updatable_attributes).except('id').merge(
                'industry' => row['industry'],
                'url_2' => row['url_2']
              )
            )
          )
  
          batch << repurpose_customer
  
          if batch.size >= batch_size
            Customer.transaction do
              batch.each(&:save!)
            end
            repurpose_import_count += batch.size
            batch.clear
          end
        end
      end
    end
    
    unless batch.empty?
      Customer.transaction do
        batch.each(&:save!)
      end
      repurpose_import_count += batch.size
    end
    
    { repurpose_import_count: repurpose_import_count }
  end
  
  
  def self.draft_import(draft_file)
    draft_count = 0
    batch_size = 2500
    batch = []
    CSV.foreach(draft_file.path, headers: true) do |row|
      next if row['tel'].present?
      existing_customer = find_by(industry: row['industry'], company: row['company'])
      next if existing_customer
  
      # 既にバッチに含まれていないか確認
      next if batch.any? { |c| c.company == row['company'] && c.industry == row['industry'] }
  
      customer = Customer.new(row.to_hash.slice(*updatable_attributes))
      next if customer.industry.nil?
      customer.status = "draft"
      customer.skip_validation = true
      batch << customer
      if batch.size >= batch_size
        Customer.transaction do
          batch.each(&:save!)
        end
        draft_count += batch.size
        batch.clear
      end
    end
    unless batch.empty?
      Customer.transaction do
        batch.each(&:save!)
      end
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
    # 2文字以上一致するかをチェック
    if required_business.present? && customer_business.present?
      # 共通する部分文字列が2文字以上あるかを確認
      common_substring = required_business.chars & customer_business.chars
      return common_substring.size >= 2
    end
    false
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