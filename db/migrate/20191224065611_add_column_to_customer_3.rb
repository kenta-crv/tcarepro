class AddColumnToCustomer3 < ActiveRecord::Migration[5.1]
  def change
    add_column :customers, :old_date, :string
    add_column :customers, :title, :string
    add_column :customers, :old_statu, :string
    add_column :customers, :other, :string
    add_column :customers, :url_2, :string
    add_column :customers, :extraction_date, :string
  end
end
