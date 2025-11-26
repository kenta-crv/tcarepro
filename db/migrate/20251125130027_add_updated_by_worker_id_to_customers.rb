class AddUpdatedByWorkerIdToCustomers < ActiveRecord::Migration[5.1]
  def change
    add_column :customers, :updated_by_worker_id, :integer
    add_index :customers, :updated_by_worker_id
  end
end
