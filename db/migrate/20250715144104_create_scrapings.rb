class CreateScrapings < ActiveRecord::Migration[5.1]
  def change
    create_table :scrapings do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :scraping_type, null: false # 例: "rakuten", "yahoo"
      t.integer :status, default: 0
      t.datetime :started_at
      t.datetime :finished_at
      t.jsonb :scraped_data # オプション：必要なら
      t.text :log # エラーメッセージなど
      t.timestamps
    end
  end
end
