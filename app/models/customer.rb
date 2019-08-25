class Customer < ApplicationRecord
  belongs_to :admin
  has_many :calls

  has_one :last_call, ->{
    order("created_at desc")
  }, class_name: :Call

  def self.import(file)
       CSV.foreach(file.path, headers:true) do |row|
       customer = find_by(id: row["id"]) || new
       customer.attributes = row.to_hash.slice(*updatable_attributes)
       next if self.where(tel: customer.tel).count > 0
       customer.save!
      end
  end

  def self.updatable_attributes
    ["company", "store", "first_name", "last_name", "first_kana", "last_kana", "tel", "tel2", "fax", "mobile", "industry", "mail", "url", "people", "postnumber", "address", "caption", "remarks", "status"]
  end

  def self.csv_attributes
    ["company", "store", "first_name", "last_name", "first_kana", "last_kana", "tel", "tel2", "fax", "mobile", "industry", "mail", "url", "people", "postnumber", "address", "caption", "remarks", "status"]
  end

  def self.generate_csv
    CSV.generate(headers:true) do |csv|
      csv << csv_attributes
      all.each do |task|
        csv << csv_attributes.map{|attr| task.send(attr)}
      end
    end
  end

  def next_customer
    Customer.where("id > ?", id).first
  end

  def prev_customer
    Customer.where("id < ?", id).last
  end
end
