class AddColumnCustomers < ActiveRecord::Migration[5.1]
  def change
    add_column :customers, :occupation, :string
  end
end
