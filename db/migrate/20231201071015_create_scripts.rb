class CreateScripts < ActiveRecord::Migration[5.1]
  def change
    create_table :scripts do |t|
      t.string :company
      t.string :name
      t.string :tel
      t.string :address
      t.string :front_talk #受付トーク
      t.string :first_talk #ファーストトーク
      t.string :introduction #自己紹介
      t.string :hearing_1
      t.string :hearing_2
      t.string :hearing_3
      t.string :hearing_4
      t.string :closing
      t.string :requirement #要件
      t.string :price
      t.string :experience
      t.string :refund
      t.string :usp
      t.string :other_receive_1
      t.string :other_receive_2
      t.string :other_receive_3
      t.string :remarks
      t.timestamps
    end
  end
end
