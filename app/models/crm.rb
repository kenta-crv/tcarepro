class Crm < ApplicationRecord
  has_many :acquisitions
  has_many :comments
  has_many :images

  def self.import(file)
      CSV.foreach(file.path, headers:true) do |row|
       crm = find_by(id: row["id"]) || new
       crm.attributes = row.to_hash.slice(*updatable_attributes)
       crm.save!
      end
  end

  def self.updatable_attributes
    [ "company","name","tel","fax","postnumber","address","mail","url","url_2","title","industry","other","other2","caption","people","rogo",
      "image","seo_rank","google_rank","foundation","contact_url","number_of_business","number_of_store","listing","settlement",
      "published_site","published_now","recruit_now","ip_address","explanation"]
  end

  def self.csv_attributes
    [ "company","name","tel","fax","postnumber","address","mail","url","url_2","title","industry","other","other2","caption","people","rogo",
      "image","seo_rank","google_rank","foundation","contact_url","number_of_business","number_of_store","listing","settlement",
      "published_site","published_now","recruit_now","ip_address","explanation"]
  end

  def self.generate_csv
    CSV.generate(headers:true) do |csv|
      csv << csv_attributes
      all.each do |task|
        csv << csv_attributes.map{|attr| task.send(attr)}
      end
    end
  end


  @@sfa_status = [
    ["契約","契約"],
    ["見込高","見込高"],
    ["見込中","見込中"],
    ["見込低","見込低"],
    ["未提案","未提案"],
    ["資料送付依頼","資料送付依頼"],
    ["資料送付済","資料送付済"],
    ["提案連絡中","提案連絡中"],
    ["NG","NG"],
    ["契約終了","契約終了"]
  ]
  end

  def self.SfaStatus
    @@sfa_status
  end
