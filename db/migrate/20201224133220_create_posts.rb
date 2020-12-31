class CreatePosts < ActiveRecord::Migration[5.1]
  def change
    create_table :posts do |t|
      t.string :title #タイトル
      t.string :file #ファイル
      t.string :choice #選択
      t.string :keyword #キーワード
      t.string :description #説明
      t.text :body #本文
      t.timestamps
    end
  end
end
