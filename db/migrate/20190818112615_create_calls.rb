class CreateCalls < ActiveRecord::Migration[5.1]
  def change
    create_table :calls do |t|
      t.string :statu
      t.datetime :time
      t.string :comment
      t.references :customer, foreign_key: true

      t.timestamps
    end
  end
end
