class CreateSmartphones < ActiveRecord::Migration[5.1]
  def change
    create_table :smartphones do |t|
      t.string :device_name, null: false
      t.string :token, null: false
      t.boolean :delete_flag, null: false, default: false
      t.timestamps
    end
  end
end
