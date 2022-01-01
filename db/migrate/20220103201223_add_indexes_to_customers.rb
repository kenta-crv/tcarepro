class AddIndexesToCustomers < ActiveRecord::Migration[5.1]
  def change
    add_index :customers, :created_at
    add_index :calls, [:customer_id, :created_at]
  end
end
