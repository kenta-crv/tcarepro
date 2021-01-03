class AddColumnToCustomers3 < ActiveRecord::Migration[5.1]
  def change
    add_column :customers, :meeting, :string #商談方法
    add_column :customers, :experience, :string #経験則
    add_column :customers, :business, :string #経験則
  end
end
