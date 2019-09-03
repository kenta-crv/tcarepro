class AddColumnToCustomer < ActiveRecord::Migration[5.1]
  def change
    add_column :customers, :memo_1, :string
    add_column :customers, :memo_2, :string
    add_column :customers, :memo_3, :string
    add_column :customers, :memo_4, :string
    add_column :customers, :memo_5, :string
  end
end
