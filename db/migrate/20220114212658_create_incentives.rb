class CreateIncentives < ActiveRecord::Migration[5.1]
  def change
    drop_table :industries

    create_table :incentives do |t|
      t.string :customer_summary_key, null: false
      t.integer :year, null: false
      t.integer :month, null: false
      t.integer :value, null: false

      t.timestamps
    end

    add_index :incentives, [:customer_summary_key, :year, :month]
  end
end
