class NgCustomer < ApplicationRecord
  belongs_to :sender, optional: true
  belongs_to :admin, optional: true
  belongs_to :customer
  belongs_to :inquiry
  
  validates :id, uniqueness: true, presence: true
  

  scope :latest, ->(sender_id){
    where(id: ContactTracking.select('max(id) as id').where(sender_id: sender_id).group(:customer_id))
  }
  self.table_name = "ng_customers"
  #customer_import
  def self.import(file,current_sender,current_admin)
      save_cont = 0
      CSV.foreach(file.path, headers:true) do |row|
       current_sender = current_sender ?  current_sender : Sender.find_by(id: row["sender"])
       ng_customer_id = row["customer"]+row["inquiry"]+(current_sender ? (current_sender.id.to_s) : (current_admin.id.to_s))
       Rails.logger.error("ng_customer_id :" + ng_customer_id)
       ng_customer = find_by(id: ng_customer_id) || new
       Rails.logger.error("ng_customer :" + ng_customer.attributes.inspect)
       ng_customer.inquiry = Inquiry.find_by(id: row["inquiry"])
       ng_customer.customer = Customer.find_by(id: row["customer"])
       ng_customer.sender = current_sender
       ng_customer.admin = current_admin
       ng_customer.id = ng_customer_id
       Rails.logger.error("ng_customer :" + ng_customer.attributes.inspect)
       ng_customer.save!
       save_cont += 1
      end
      save_cont
  end
end
