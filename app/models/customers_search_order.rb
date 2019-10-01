class CustomersSearchOrder < ApplicationRecord
  belongs_to :admin
  #def prev
  #  customers_search_order.customers.order('published_at desk, id desc').where('published_at <= ? and id < ?', published_at, id).first
  #end

  #def next
  #  customers_search_order.customers.order('published_at desk, id desc').where('published_at >= ? and id > ?', published_at, id).reverse.first
  #end
end
