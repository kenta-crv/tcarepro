class Crm < ApplicationRecord
  has_many :acquisitions
  has_many :comments
  has_many :images

  def self.import(file)
      CSV.foreach(file.path, headers:true) do |row|
       crm = find_by(id: row["id"]) || new
       crm.attributes = row.to_hash.slice(*updatable_attributes)
       next if self.where(tel: crm.tel).count > 0
       crm.save!
      end
  end

  def self.updatable_attributes
    ["company","first_name","last_name","first_kana","last_kana","tel","mobile","fax","mail","postnumber","prefecture","city","town","building","url","item","statu","price","number","history","area","target","next", "content","comment"]
  end

  def self.csv_attributes
    ["company","first_name","last_name","first_kana","last_kana","tel","mobile","fax","mail","postnumber","prefecture","city","town","building","url","item","statu","price","number","history","area","target","next", "content","comment"]
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
    ["対象外","対象外"],
    ["NG","NG"],
    ["返答待","返答待"]
  ]

  def self.SfaStatus
    @@sfa_status
  end
end
