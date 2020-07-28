class Customer2 < ApplicationRecord
  has_many :calls, :foreign_key => "customer_id"
  
  self.table_name = "customers"
end
