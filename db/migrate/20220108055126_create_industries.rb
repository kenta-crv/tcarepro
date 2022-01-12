class CreateIndustries < ActiveRecord::Migration[5.1]
  def change
    create_table :industries do |t|
      t.string :key, null: false
      t.integer :incentive

      t.timestamps
    end
  end
end
