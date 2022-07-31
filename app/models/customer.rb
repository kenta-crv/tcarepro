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

  has_one :last_contact, ->{
    order("created_at desc")
  }, class_name: ContactTracking

  scope :last_contact_trackings, ->(sender_id, status){
    joins(:contact_trackings).where(contact_trackings: { id: ContactTracking.latest(sender_id).select(:id), status: status })
  }

  # Direct Mail Contact Trackings
  has_many :direct_mail_contact_trackings
  has_one :direct_mail_contact_tracking, ->{
    eager_load(:direct_mail_contact_trackings).order(sended_at: :desc)
  }

  has_one :last_mail_contact, ->{
    order("created_at desc")
  }, class_name: DirectMailContactTracking

  scope :last_mail_contact_trackings, ->(status){
    joins(:direct_mail_contact_trackings).where(direct_mail_contact_trackings: { status: status })
  }
  scope :between_created_at, ->(from, to){
    where(created_at: from..to)
  }

  scope :between_updated_at, ->(from, to){
    where(updated_at: from..to).where.not(tel: nil)
  }

  scope :ltec_calls_count, ->(count){
    filter_ids = joins(:calls).group("calls.customer_id").having('count(*) <= ?',count).count.keys
    where(id: filter_ids)
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

  @@genre_status = [
    ["人材関連業","人材関連業"],
    ["┗人材派遣","┗人材派遣"],
    ["┗人材紹介","┗人材紹介"],
    ["┗外国人人材紹介","┗外国人人材紹介"],
    ["┗協同組合","┗協同組合"],
    ["┗求人サービス","┗求人サービス"],

    ["広告業","広告業"],
    ["┗紙媒体印刷業界","┗紙媒体印刷業界"],
    ["┗看板業界","┗看板業界"],
    ["┗その他印刷業界","┗その他印刷業界"],
    ["┗インターネット広告代理店","┗インターネット広告代理店"],
    ["┗企業展示会・販促イベント業界","┗企業展示会・販促イベント業界"],
    ["┗SNS広告業","┗SNS広告業"],
    ["┗その他広告業界の会社","┗その他広告業界の会社"],

    ["マーケ・コンサルティング業","マーケ・コンサルティング業"],
    ["┗マーケティング業界","┗マーケティング業界"],
    ["┗土木・建築コンサルティング業界の会社","┗土木・建築コンサルティング業界の会社"],
    ["┗不動産コンサルティング業界の会社","┗不動産コンサルティング業界の会社"],
    ["┗経営コンサルティング業界の会社","┗経営コンサルティング業界の会社"],
    ["┗ITコンサルティング業界の会社","┗ITコンサルティング業界の会社"],
    ["┗その他コンサルティング業界の会社","┗その他コンサルティング業界の会社"],
    ["┗販売促進コンサルティング業界の会社","┗販売促進コンサルティング業界の会社"],
    ["┗Webマーケティング業界の会社","┗Webマーケティング業界の会社"],
    ["┗組織・人事コンサルティング業界","┗組織・人事コンサルティング業界"],
    ["┗医療系コンサルティング業界の会社","┗医療系コンサルティング業界の会社"],
    ["┗起業コンサルティング業界の会社","┗起業コンサルティング業界の会社"],
    ["┗財務・監査コンサルティング業界","┗財務・監査コンサルティング業界"],
    ["┗広告運用コンサルティング業界の会社","┗広告運用コンサルティング業界の会社"],
    ["┗コスト削減コンサルティング業界の会社","┗コスト削減コンサルティング業界の会社"],
    ["┗飲食店コンサルティング業界の会社","┗飲食店コンサルティング業界の会社"],
    ["┗製造業コンサルティング業界の会社","┗製造業コンサルティング業界の会社"],
    ["┗総合コンサルティング業界の会社","┗総合コンサルティング業界の会社"],

    ["飲食店","飲食店"],
    ["┗フレンチ・モダンフレンチ","┗フレンチ・モダンフレンチ"],
    ["┗イタリアン","┗イタリアン"],
    ["┗日本料理・懐石料理・会席料理・割烹料理","┗日本料理・懐石料理・会席料理・割烹料理"],
    ["┗中華","┗中華"],
    ["┗その他日本料理","┗その他日本料理"],
    ["┗その他アジア料理","┗その他アジア料理"],
    ["┗カフェ・スイーツ","┗カフェ・スイーツ"],
    ["┗その他","┗その他"],

    ["美容業","美容業"],
    ["┗美容院","┗美容院"],
    ["┗理容院","┗理容院"],
    ["┗エステサロン","┗エステサロン"],
    ["┗整体","┗整体"],
    ["┗カイロプラティクス・リラクゼーション","┗リラクゼーション"],
    ["┗ネイル・まつ毛サロン","┗ネイル・まつ毛サロン"],
    ["┗その他サロン","┗その他サロン"],

    ["IT・エンジニア・Web制作","IT・エンジニア・Web制作"],
    ["┗ホームページ制作","┗ホームページ制作"],
    ["┗システム受託開発","┗システム受託開発"],
    ["┗システム開発","┗システム開発"],
    ["┗Webサービス・アプリ開発","┗Webサービス・アプリ開発"],
    ["┗ソフトウェア専門商社・ソフトウェア専門商社"],
    ["┗デジタルコンテンツ","┗デジタルコンテンツ"],
    ["┗クラウド・フィンテック業界","┗クラウド・フィンテック業界"],
    ["┗情報セキュリティサービス業界の会社","┗情報セキュリティサービス業界の会社"],
    ["┗その他IT業界","┗その他IT業界"],

    ["製造業","製造業"],
    ["┗機械関係","┗機械関係"],
    ["┗金属・鉄鋼関係","┗金属・鉄鋼関係"],
    ["┗電子部品・電子デバイス関連","┗電子部品・電子デバイス関連"],
    ["┗化学関連","┗化学関連"],
    ["┗建築・住宅関係","┗建築・住宅関係"],
    ["┗医療品関係","┗医療品関係"],
    ["┗食品・水産関係","┗食品・水産関係"],
    ["┗その他製造業","┗その他製造業"],

    ["福祉・医療","福祉・医療"],
    ["┗老人ホーム","┗老人ホーム"],
    ["┗訪問介護","┗訪問介護"],
    ["┗障害者福祉","┗障害者福祉"],
    ["┗介護用品・家庭医療機器業","┗介護用品・家庭医療機器業"],
    ["┗歯医者","┗歯医者"],
    ["┗病院","┗病院"],
    ["┗その他医療福祉","┗その他医療福祉"],

    ["商社","商社"],
    ["┗その他専門商社","┗その他専門商社"],
    ["┗機械専門商社","┗機械専門商社"],
    ["┗食品専門商社","┗食品専門商社"],
    ["┗工業用機械専門商社","┗工業用機械専門商社"],
    ["┗農産物食品専門商社","┗農産物食品専門商社"],
    ["┗水産物食品専門商社","┗水産物食品専門商社"],
    ["┗繊維・アパレル専門商社","┗繊維・アパレル専門商社"],
    ["┗日用品・化粧品専門商社","┗日用品・化粧品専門商社"],
    ["┗化学品・医薬品専門商社","┗化学品・医薬品専門商社"],
    ["┗医療機器・器具専門商社","┗医療機器・器具専門商社"],
    ["┗工業用機械専門商社","┗工業用機械専門商社"],
    ["┗鉄鋼・金属専門商社","┗鉄鋼・金属専門商社"],
    ["┗雑貨専門商社","┗雑貨専門商社"],
    ["┗食肉・卵専門商社","┗食肉・卵専門商社"],
    ["┗農林水産用機械専門商社","┗農林水産用機械専門商社"],
    ["┗電子部品専門商社","┗電子部品専門商社"],
    ["┗紙・パルプ専門商社","┗紙・パルプ専門商社"],
    ["┗総合商社","┗総合商社"],

    ["土木建設業","土木建設業"],
    ["┗その他建築専門工事","┗その他建築専門工事"],
    ["┗土木工事","┗土木工事"],
    ["┗居住用リフォーム","┗居住用リフォーム"],
    ["┗衛生設備工事","┗衛生設備工事"],
    ["┗建造物建築","┗建造物建築"],
    ["┗とび","┗とび"],
    ["┗交通関連土木工事","┗交通関連土木工事"],
    ["┗注文型住宅建築","┗注文型住宅建築"],
    ["┗電気設備工事","┗電気設備工事"],
    ["┗住宅・事業所向け設備","┗住宅・事業所向け設備"],
    ["┗空調設備工事","┗空調設備工事"],
    ["┗事業用リフォーム","┗事業用リフォーム"],
    ["┗土木・建築設計","┗土木・建築設計"],
    ["┗建造物解体工事","┗建造物解体工事"],
    ["┗河川・港湾工事","┗河川・港湾工事"],
    ["┗太陽光パネル","┗太陽光パネル"],
    ["┗造園工事","┗造園工事"],
    ["┗産業用電気設備工事","┗産業用電気設備工事"],
    ["┗通信設備工事","┗通信設備工事"],
    ["┗その他リフォーム","┗その他リフォーム"],
    ["┗窯業系建材・石材製造","┗窯業系建材・石材製造"],
    ["┗大型商業施設・公共施設建設","┗大型商業施設・公共施設建設"],
    ["┗木材系建材製造","┗木材系建材製造"],
    ["┗プラント設備工事","┗プラント設備工事"],
    ["┗総合土木工事","┗総合土木工事"],
    ["┗金属系建材製造","┗金属系建材製造"],
    ["┗インテリアデザイン","┗インテリアデザイン"],
    ["┗分譲型住宅建築業界","┗分譲型住宅建築業界"],
    ["┗ビル建設","┗ビル建設"],
    ["┗マンション建築","┗マンション建築"],
    ["┗樹脂系建材製造","┗樹脂系建材製造"],
    ["┗ゼネコン","┗ゼネコン"],
    ["┗燃料タンク工事","┗燃料タンク工事"],


    ["教育業","教育業"],
    ["┗企業研修業","┗企業研修業"],
    ["┗学習塾","┗学習塾"],
    ["┗資格取得","┗資格取得"],
    ["┗児童・保育","┗児童・保育"],
    ["┗学校","┗学校"],
    ["┗その他教育業","┗その他教育業"],

    ["専門サービス業","専門サービス業"],
    ["┗税理士","┗税理士"],
    ["┗社会保険労務士","┗社会保険労務士"],
    ["┗弁護士","┗弁護士"],
    ["┗行政書士","┗行政書士"],
    ["┗司法書士","┗司法書士"],
    ["┗その他士業","┗その他士業"],

    ["その他","その他"],
    ["┗農林水産業","┗農林水産業"],
    ["┗エンタメ業","┗エンタメ業"],
    ["┗生活用品業","┗生活用品業"],
    ["┗運輸・物流","┗運輸・物流"],
    ["┗不動産業","┗不動産業"],
    ["┗金融業","┗金融業"],
  ]
  def self.GenreStatus
    @@genre_status
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

  private

  def scraping
    @scraping ||= Scraping.new
  end
end
