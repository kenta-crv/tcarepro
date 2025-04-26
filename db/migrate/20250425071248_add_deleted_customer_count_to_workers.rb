class AddDeletedCustomerCountToWorkers < ActiveRecord::Migration[5.1]
  def change
    add_column :workers, :deleted_customer_count, :integer, default: 0
  end
end
