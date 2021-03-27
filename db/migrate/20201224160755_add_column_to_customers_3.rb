class AddColumnToCustomers3 < ActiveRecord::Migration[5.1]
  def change
    add_column :customers, :contact_url, :string #商談方法
    add_column :customers, :meeting, :string #商談方法
    add_column :customers, :experience, :string #経験則
    add_column :customers, :extraction_count, :string #リスト
    add_column :customers, :send_count, :string #送信
    add_reference :customers, :worker, foreign_key: true
  end
end
