class CreateDetails < ActiveRecord::Migration[5.1]
  def change
    create_table :details do |t|
      t.string :name
      t.string :product_type
      t.string :method
      t.integer :tel
      t.string :post
      t.string :address
      t.string :point
      t.references :prefecture, foreign_key: true

      t.timestamps
    end
  end
end
