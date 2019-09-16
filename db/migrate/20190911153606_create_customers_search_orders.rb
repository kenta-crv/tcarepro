class CreateCustomersSearchOrders < ActiveRecord::Migration[5.1]
  def change
    create_table :customers_search_orders do |t|
       t.integer :admin_id
       t.integer :customer_id
       t.integer :prev_customer_id
       t.integer :next_customer_id
      t.timestamps
    end
  end
end
