class CreateInvoices < ActiveRecord::Migration[5.1]
  def change
    create_table :invoices do |t|
      t.references :crm, foreign_key: true
      t.string :status #ステータス
      t.string :deadline #期限
      t.string :payment #入金日
      t.string :subject #件名
      t.string :item1 #商品名
      t.string :item2 #商品名
      t.string :item3 #商品名
      t.string :item4 #商品名
      t.string :item5 #商品名

      t.integer :price1 #商品名
      t.integer :price2 #商品名
      t.integer :price3 #商品名
      t.integer :price4 #商品名
      t.integer :price5 #商品名

      t.integer :quantity1 #数量
      t.integer :quantity2 #数量
      t.integer :quantity3 #数量
      t.integer :quantity4 #数量
      t.integer :quantity5 #数量
      t.timestamps
    end
  end
end
