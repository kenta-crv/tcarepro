class AddIndustryToClients < ActiveRecord::Migration[5.1]
  def change
    add_column :clients, :industry, :string, index: true
    add_index :calls, :statu
  end
end
