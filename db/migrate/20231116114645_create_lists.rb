class CreateLists < ActiveRecord::Migration[5.1]
  def change
    create_table :lists do |t|
      t.references :worker, foreign_key: true
      t.string :number #抽出件数
      t.string :url #スプレッドシートURL
      t.string :check_1
      t.string :check_2
      t.string :check_3
      t.string :check_4
      t.string :check_5
      t.string :check_6
      t.string :check_7
      t.string :check_8
      t.string :check_9
      t.string :check_10
      t.timestamps
    end
  end
end
