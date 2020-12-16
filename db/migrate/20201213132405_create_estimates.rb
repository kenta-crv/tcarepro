class CreateEstimates < ActiveRecord::Migration[5.1]
  def change
    create_table :estimates do |t|
      t.references :customer, foreign_key: true
      t.string :title #題名
      t.string :status #ステータス
      t.string :deadline #期限
      t.string :payment #入金日
      t.string :subject #件名
      t.string :item1 #商品名
      t.string :item2 #商品名
      t.string :item3 #商品名
      t.string :item4 #商品名
      t.string :item5 #商品名

      t.string :price1 #商品名
      t.string :price2 #商品名
      t.string :price3 #商品名
      t.string :price4 #商品名
      t.string :price5 #商品名

      t.string :quantity1 #数量
      t.string :quantity2 #数量
      t.string :quantity3 #数量
      t.string :quantity4 #数量
      t.string :quantity5 #数量

      t.timestamps
    end
  end
end
