class CreateSmartphones < ActiveRecord::Migration[5.1]
  def change
    create_table "devices", force: :cascade do |t|
      t.integer "id", unique: true
      t.string "device_name", null: false
      t.string "token", null: false
      t.boolean "delete_flag", default: false, null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
    end
  end
end
