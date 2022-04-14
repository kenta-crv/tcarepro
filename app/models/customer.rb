require 'scraping'

class Customer < ApplicationRecord
  #belongs_to :admin
  belongs_to :user, optional: true
  belongs_to :worker, optional: true
  belongs_to :client, optional: true
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

  validates :tel, :exclusion => ["%080", "%090", "%0120", "%0088", "%070"]
  validates :tel, presence: true, if: -> { extraction_count.blank?}, on: :update
  #validates :address, presence: true, if: -> { extraction_count.blank?}, on: :update
  #validates :business, presence: true, if: -> { extraction_count.blank?}, on: :update
  validates :extraction_count, presence: true, if: -> { tel.blank?}, on: :update

#customer_import
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
    ["id","company","first_name","tel","mobile","industry","mail","url","url_2","postnumber","address","people",
     "caption","choice","inflow","business","other","history","area","target","meeting","experience","price",
     "number","start","remarks","extraction_count","send_count"]
  end

  #update_import
  def self.update_import(update_file)
    save_cnt = 0
    CSV.foreach(update_file.path, headers: true) do |row|
      customer = find_by(id: row["id"]) || new
      customer.attributes = row.to_hash.slice(*updatable_attributes)
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
       #next if self.where(company: customer.company).where(industry: nil).count > 0
       #next if self.where(company: customer.company).where(industry: customer.industry).count > 0
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
    ["id","company","first_name","tel","mobile","industry","mail","url","url_2","postnumber","address","people",
     "caption","choice","inflow","business","other","history","area","target","meeting","experience","price",
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

  @@ChoiceItems = [
    [1,"SORAIRO関東"],
    [2,"SORAIRO九州"],
    [3,"ティンロンジャパン"],
    [4,"アイアットOEC"]
  ]
  def self.ChoiceItems
    @@ChoiceItems
  end

  @@old_status = [
    [0,"不在"],
    [1,"担当者不在"],
    [2,"見込"],
    [3,"折返待"],
    ["app","APP"],
    ["ng_now","今は結構"],
    ["ng_foreign","外国人NG"],
    ["ng_front","フロントNG"]
  ]
  def self.Old_status
    @@old_status
  end

  @@business_status = [
    ["人材関連業","人材関連業"],
    ["広告業","広告業"],
    ["マーケティング業","マーケティング業"],
    ["コンサルティング業","コンサルティング業"],
    ["飲食店","飲食店"],
    ["美容業","美容業"],
    ["製造業","製造業"],
    ["Web制作","Web制作"],
    ["IT・エンジニア","IT・エンジニア"],
    ["建設土木業","建設土木業"],
    ["農林水産業","農林水産業"],
    ["製造業","製造業"],
    ["福祉・医療","福祉・医療"],
    ["不動産","不動産"],
    ["商社","商社"],
    ["エンタメ業","エンタメ業"],
    ["運輸・物流","運輸・物流"],
    ["生活用品業","生活用品業"],
    ["金融業","金融業"],
    ["教育業","教育業"],
    ["専門サービス業","専門サービス業"],
    ["その他","その他"]
  ]
  def self.BusinessStatus
    @@business_status
  end

  @Human_status = [
    ["人材紹介","人材紹介"],
    ["人材派遣","人材派遣"],
    ["外国人紹介・協同組合","外国人紹介・協同組合"],
    ["求人サービス","求人サービス"],]
  def self.HumanStatus
    @@human_status
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

  def contact_url
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

  private

  def scraping
    @scraping ||= Scraping.new
  end
end
