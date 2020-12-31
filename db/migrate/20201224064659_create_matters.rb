class CreateMatters < ActiveRecord::Migration[5.1]
  def change
    create_table :matters do |t|
      t.string :title #タイトル
      t.string :description #詳細
      t.string :possible #可能
      t.string :impossible #不可能
      t.string :information #送信情報
      t.string :attention #注意
      t.references :admin
      t.references :member
      t.timestamps
    end
  end
end
