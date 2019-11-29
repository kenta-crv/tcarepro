class CreateSmartphoneLogs < ActiveRecord::Migration[5.1]
  def change
    create_table :smartphone_logs do |t|
      t.string :token, null: false
      t.string :log_data, null: false
      t.datetime :created_at, null: false
    end
  end
end
