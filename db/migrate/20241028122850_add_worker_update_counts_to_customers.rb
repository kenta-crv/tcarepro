class AddWorkerUpdateCountsToCustomers < ActiveRecord::Migration[5.1]
  def change
    add_column :customers, :worker_update_count_day, :integer
    add_column :customers, :worker_update_count_week, :integer
    add_column :customers, :worker_update_count_month, :integer
  end
end
