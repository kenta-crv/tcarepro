class CreateWriters < ActiveRecord::Migration[5.1]
  def change
    create_table :writers do |t|
      t.references :worker, foreign_key: true
      t.string :title_1
      t.string :url_1
      t.string :title_2
      t.string :url_2
      t.string :title_3
      t.string :url_3
      t.string :title_4
      t.string :url_4
      t.string :title_5
      t.string :url_5
      t.string :title_6
      t.string :url_6
      t.string :title_7
      t.string :url_7
      t.string :title_8
      t.string :url_8
      t.string :title_9
      t.string :url_9
      t.string :title_10
      t.string :url_10
      t.timestamps
    end
  end
end
