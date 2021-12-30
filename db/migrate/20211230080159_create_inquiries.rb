class CreateInquiries < ActiveRecord::Migration[5.1]
  def change
    create_table :inquiries do |t|
      t.string :headline #案件名
      t.string :from_company #会社名
      t.string :person #担当者
      t.string :person_kana #タントウシャ
      t.string :from_tel #電話番号
      t.string :from_fax #FAX番号
      t.string :from_mail #メールアドレス
      t.string :url #HP
      t.string :address #住所
      t.string :title #件名
      t.string :content #本文
      t.timestamps
    end
  end
end
