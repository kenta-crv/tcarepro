require 'scraping'

class Customer < ApplicationRecord
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
  }, class_name: ContactTracking

  scope :last_contact_trackings, ->(sender_id, status){
    joins(:contact_trackings).where(contact_trackings: { id: ContactTracking.latest(sender_id).select(:id), status: status })
  }

  scope :last_contact_trackings_only, ->(sender_id){
    joins(:contact_trackings).where(contact_trackings: { id: ContactTracking.latest(sender_id).select(:id) })
  }

  # Direct Mail Contact Trackings
  has_many :direct_mail_contact_trackings
  has_one :direct_mail_contact_tracking, ->{
    eager_load(:direct_mail_contact_trackings).order(sended_at: :desc)
  }

  #has_one :last_mail_contact, ->{
  #  order("created_at desc")
  #}, class_name: DirectMailContactTracking

  #scope :last_mail_contact_trackings, ->(status){
  #  joins(:direct_mail_contact_trackings).where(direct_mail_contact_trackings: { status: status })
  #}
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
    eager_load(:contact_trackings).marge(ContactTracking.before_sended_at(sended_at))
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

  scope :with_status, -> (statuses) {
  if statuses.present?
    where(status: statuses)
  end
}

  scope :with_is_contact_tracking, -> is_contact_tracking {
    if is_contact_tracking == "true"
      contact_trackings.exists?
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


  validates :tel, :exclusion => ["%080", "%090", "%0120", "%0088", "%070"]

  def self.import(file)
    save_cont = 0
    CSV.foreach(file.path, headers:true) do |row|
     customer = find_by(id: row["id"]) || new
     customer.attributes = row.to_hash.slice(*updatable_attributes)
     next if customer.industry == nil
     next if self.where(tel: customer.tel).where(industry: nil).count > 0
     next if self.where(tel: customer.tel).where(industry: customer.industry).count > 0
     customer.save!
     save_cont += 1
    end
    save_cont
  end
  def self.updatable_attributes
    ["id","company","tel","address","url","url_2","title","industry","mail","first_name","postnumber","people",
     "caption","business","genre","mobile","choice","inflow","other","history","area","target","meeting","experience","price",
     "number","start","remarks","extraction_count","send_count"]
  end

  #update_import
  def self.update_import(update_file)
    save_cnt = 0
    CSV.foreach(update_file.path, headers: true) do |row|
      customer = find_by(id: row["id"]) || new
      customer.attributes = row.to_hash.slice(*updatable_attributes)
      next if customer.industry == nil
      next if self.where(tel: customer.tel).where(industry: nil).count > 0
      next if self.where(tel: customer.tel).where(industry: customer.industry).count > 0
      customer.save!
      save_cnt += 1
    end
    save_cnt
  end
 
#tcare_import
  def self.tcare_import(tcare_file)
      save_cont = 0
      CSV.foreach(tcare_file.path, headers:true) do |row|
       customer = find_by(id: row["id"]) || new
       customer.attributes = row.to_hash.slice(*updatable_attributes)
       next if customer.industry == nil
       customer.save!
       save_cont += 1
      end
      save_cont
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
    ["id","company","tel","address","url","url_2","title","industry","mail","first_name","postnumber","people",
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

  @@extraction_status = [
    ["リスト抽出不可","リスト抽出不可"]
  ]
  def self.ExtractionStatus
    @@extraction_status
  end

  @@send_status = [
    ["メール送信済","メール送信済"]
  ]
  def self.SendStatus
    @@send_status
  end

  enum status: {draft: 0, published: 1}

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

  private

  def scraping
    @scraping ||= Scraping.new
  end
end
