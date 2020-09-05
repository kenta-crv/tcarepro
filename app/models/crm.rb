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
    [ "company","first_name","tel","fax","prefecture","mail","url","item","statu", "price","number",
    "history","area","target", "next","date_time", "content","comment", "choice"]
  end

  def self.csv_attributes
    [ "company","first_name","tel","fax","prefecture","mail","url","item","statu", "price","number",
    "history","area","target", "next","date_time", "content","comment", "choice"]
  end

  def self.generate_csv
    CSV.generate(headers:true) do |csv|
      csv << csv_attributes
      all.each do |task|
        csv << csv_attributes.map{|attr| task.send(attr)}
      end
    end
  end

  def self.SfaStatus
    @@sfa_status
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
