class AddColumnToSelect < ActiveRecord::Migration[5.1]
  def change
    add_column :workers, :select, :string
  end
end
