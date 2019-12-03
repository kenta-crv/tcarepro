class AddColumnToCustomer2 < ActiveRecord::Migration[5.1]
  def change
    add_column :customers, :choice, :string
  end
end
