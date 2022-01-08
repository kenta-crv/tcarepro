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

  validates :tel, :exclusion => ["%080", "%090", "%0120", "%0088", "%070"]
  validates :tel, presence: true, if: -> { extraction_count.blank?}, on: :update
  validates :address, presence: true, if: -> { extraction_count.blank?}, on: :update
  validates :business, presence: true, if: -> { extraction_count.blank?}, on: :update
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
    ["company","store","first_name","last_name","first_kana","last_kana","tel","tel2","fax","mobile","industry","mail","url","people","postnumber","address",
     "caption","status","title","other","url_2","customer_tel","choice","inflow","business","history","area","target","meeting","experience","price",
     "number","start","remarks","business","extraction_count","send_count"]
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
    ["company","store","first_name","last_name","first_kana","last_kana","tel","tel2","fax","mobile","industry","mail","url","people","postnumber","address",
     "caption","status","title","other","url_2","choice","inflow","business","history","area","target","meeting","experience","price",
     "number","start","remarks","business","extraction_count","send_count"]
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
    ["人材紹介業","人材紹介業"],
    ["人材派遣業","人材派遣業"],
    ["求人会社","求人会社"],
    ["広告業","広告業"],
    ["マーケティング業","マーケティング業"],
    ["飲食店","飲食店"],
    ["美容院","美容院"],
    ["製造業","製造業"],
    ["Web制作","Web制作"],
    ["IT・エンジニア","IT・エンジニア"],
    ["建設土木業","建設土木業"],
    ["農林水産業","農林水産業"],
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

end
