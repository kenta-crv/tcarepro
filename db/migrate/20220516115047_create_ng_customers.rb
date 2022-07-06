class CreateNgCustomers < ActiveRecord::Migration[5.1]
  def change
    create_table :ng_customers do |t|
    t.integer "customer_id", null: false
    t.integer "inquiry_id", null: false
    t.integer "sender_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
      t.timestamps
    end
  end
end
