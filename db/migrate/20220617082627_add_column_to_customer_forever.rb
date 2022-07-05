class AddColumnToCustomerForever < ActiveRecord::Migration[5.1]
  def change
    add_column :customers, :forever, :string
  end
end
