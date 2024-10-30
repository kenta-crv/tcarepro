class CreateEmailHistories < ActiveRecord::Migration[5.1]
  def change
    create_table :email_histories do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :inquiry, null: false, foreign_key: true
      t.datetime :sent_at, null: false
      t.string :status, null: false, default: "pending"

      t.timestamps
    end
  end
end
