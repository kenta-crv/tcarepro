class CreateCounts < ActiveRecord::Migration[5.1]
  def change
    create_table :counts do |t|
      t.string :company
      t.string :title
      t.string :statu
      t.datetime :time
      t.string :comment
      t.references :customer, foreign_key: true
      t.references :sender, foreign_key: true
      t.timestamps
      t.timestamps
    end
  end
end
