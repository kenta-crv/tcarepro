class AddColumnToContract < ActiveRecord::Migration[5.1]
  def change
    add_column :contracts, :price, :string
    add_column :contracts, :upper, :string
    add_column :contracts, :payment, :string
    add_column :contracts, :statu, :string
  end
end
