class AddContractIdToCalls < ActiveRecord::Migration[5.1]
  def change
    add_column :calls, :contract_id, :integer
  end
end
