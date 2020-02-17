class CreateOrders < ActiveRecord::Migration[5.1]
  def change
    create_table :orders do |t|
      t.string :title #題名
      t.string :list #リスト名
      t.string :tab #実施タブ
      #リスト制作
      t.string :within #対象内
      t.string :without #対象外
      #メール送信
      t.string :company #会社名
      t.string :name #名前
      t.string :name_kana #ナマエ
      t.string :tel #電話番号
      t.string :address #住所
      t.string :url #url
      t.string :mail #mail
      t.string :message #送信内容
      #共通
      t.string :warning #注意点
      t.string :remarks #備考
      t.timestamps
    end
  end
end
