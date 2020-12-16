class AddColumnToCustomers < ActiveRecord::Migration[5.1]
  def change
    add_column :customers, :inflow, :string #流入元
    add_column :customers, :business, :string #事業内容
    add_column :customers, :price, :string #単価
    add_column :customers, :number, :string #件数
    add_column :customers, :history, :string #過去アポ利用履歴
    add_column :customers, :area, :string #ターゲットエリア
    add_column :customers, :target, :string #対象者
    add_column :customers, :start, :date #開始時期

    remove_column :customers, :memo_1, :string
    remove_column :customers, :memo_2, :string
    remove_column :customers, :memo_3, :string
    remove_column :customers, :memo_4, :string
    remove_column :customers, :old_date, :string
    remove_column :customers, :old_statu, :string
    remove_column :customers, :extraction_date, :string
    remove_column :customers, :occupation, :string
  end
end
