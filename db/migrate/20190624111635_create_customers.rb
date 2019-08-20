class CreateCustomers < ActiveRecord::Migration[5.1]
  def change
    create_table :customers do |t|
      t.string :company #会社名
      t.string :store #店舗名
      t.string :first_name #代表者
      t.string :last_name #名前
      t.string :first_kana #ミョウジ
      t.string :last_kana #ナマエ
      t.string :tel #電話番号1
      t.string :tel2 #電話番号2
      t.string :fax #FAX番号
      t.string :mobile #携帯番号
      t.string :industry #業種
      t.string :mail #メール
      t.string :url #URL
      t.string :people #人数
      t.string :postnumber #郵便番号
      t.string :address #住所
      t.string :caption #資本金
      t.string :remarks #履歴

      t.string :status #履歴

      t.timestamps
    end
  end
end
