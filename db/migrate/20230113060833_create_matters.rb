class CreateMatters < ActiveRecord::Migration[5.1]
  def change
    create_table :matters do |t|
      t.string :sheets
      t.string :tab
      t.string :area
      t.string :business
      t.string :scale
      t.string :warning
      t.string :other
      t.timestamps
    end
  end
end
