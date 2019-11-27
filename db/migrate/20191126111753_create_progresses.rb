class CreateProgresses < ActiveRecord::Migration[5.1]
  def change
    create_table :progresses do |t|
      t.references :crm, foreign_key: true
      t.string :statu #ステータス
      t.string :price #単価
      t.string :number #件数
      t.string :history #過去アポ利用履歴
      t.string :area #ターゲットエリア
      t.string :target #対象者
      t.string :next #次回営業日
      t.string :content #サービス内容
      t.string :comment #コメント
      t.timestamps
    end
  end
end
