class RemoveSenderIdFromCustomers < ActiveRecord::Migration[5.1]
  def change
    remove_foreign_key :related_table_name, :customers  # ここで関連テーブル名を指定
  end
end