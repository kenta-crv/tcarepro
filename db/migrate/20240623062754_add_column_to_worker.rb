class AddColumnToWorker < ActiveRecord::Migration[5.1]
  def change
    add_column :workers, :number_code, :integer
  end
end
