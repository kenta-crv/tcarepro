class CreateTests < ActiveRecord::Migration[5.1]
  def change
    create_table :tests do |t|
      t.references :worker, foreign_key: true
      t.string :company
      t.string :tel
      t.string :address
      t.string :title
      t.string :business
      t.string :genre
      t.string :url
      t.string :contact_url
      t.string :url_2
      t.string :store
      t.timestamps
    end
  end
end
