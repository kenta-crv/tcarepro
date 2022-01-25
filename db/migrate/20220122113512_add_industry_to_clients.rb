class AddIndustryToClients < ActiveRecord::Migration[5.1]
  def change
    add_column :clients, :industry, :string, null: false, index: true
    add_index :calls, :statu
  end
end
