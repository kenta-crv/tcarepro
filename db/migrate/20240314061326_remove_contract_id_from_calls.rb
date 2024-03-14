class RemoveContractIdFromCalls < ActiveRecord::Migration[5.1]
  def change
    remove_column :calls, :contract_id, :integer
  end
end
