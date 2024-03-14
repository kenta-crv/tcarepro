class AddColumnToScript < ActiveRecord::Migration[5.1]
  def change
    add_column :customers, :requirement_title, :string
    add_column :customers, :price_title, :string
    add_column :customers, :experienc_title, :string
    add_column :customers, :refund_title, :string
    add_column :customers, :usp_title, :string
    add_column :customers, :other_receive_1_title, :string
    add_column :customers, :other_receive_2_title, :string
    add_column :customers, :other_receive_3_title, :string
  end
end
