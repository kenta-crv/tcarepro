class ChangeColumnOnInvoices < ActiveRecord::Migration[5.1]
  def change
    change_column :invoices, :price1, :integer
    change_column :invoices, :quantity1, :integer
    change_column :invoices, :price2, :integer
    change_column :invoices, :quantity2, :integer
    change_column :invoices, :price3, :integer
    change_column :invoices, :quantity3, :integer
    change_column :invoices, :price4, :integer
    change_column :invoices, :quantity4, :integer
    change_column :invoices, :price5, :integer
    change_column :invoices, :quantity5, :integer
  end
end
