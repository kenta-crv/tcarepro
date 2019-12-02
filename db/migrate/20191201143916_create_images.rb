class CreateImages < ActiveRecord::Migration[5.1]
  def change
    create_table :images do |t|
      t.references :crm, foreign_key: true
      t.string :name
      t.string :views
      t.string :image
      t.timestamps
    end
  end
end
