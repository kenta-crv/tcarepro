class CreateCrowdworks < ActiveRecord::Migration[5.1]
  def change
    create_table :crowdworks do |t|
      t.string :title
      t.string :sheet
      t.string :tab
      t.string :area
      t.string :business
      t.string :genre
      t.string :bad
      t.string :attention
      t.references :worker, null: true, foreign_key: true
      t.timestamps
    end
  end
end
