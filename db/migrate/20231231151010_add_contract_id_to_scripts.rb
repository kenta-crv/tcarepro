class AddContractIdToScripts < ActiveRecord::Migration[5.1]
  def change
    add_reference :scripts, :contract, foreign_key: true
  end
end
