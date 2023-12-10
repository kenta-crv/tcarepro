class AddSearchAndTargetToContracts < ActiveRecord::Migration[5.1]
  def change
    add_column :contracts, :search, :jsonb, default: '{}'
    add_column :contracts, :target, :jsonb, default: '{}'
  end
end
