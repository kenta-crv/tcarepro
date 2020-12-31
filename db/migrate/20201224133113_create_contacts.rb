class CreateContacts < ActiveRecord::Migration[5.1]
  def change
    create_table :contacts do |t|
      t.string :company #会社名
      t.string :name  #代表者名
      t.string :tel #電話番号
      t.string :address #住所
      t.string :email #メールアドレス
      t.string :subject
      t.string :message
      t.timestamps
    end
  end
end
