class AddColumnToScript < ActiveRecord::Migration[5.1]
  def change
    add_column :scripts, :requirement_title, :string
    add_column :scripts, :price_title, :string
    add_column :scripts, :experience_title, :string
    add_column :scripts, :refund_title, :string
    add_column :scripts, :usp_title, :string
    add_column :scripts, :other_receive_1_title, :string
    add_column :scripts, :other_receive_2_title, :string
    add_column :scripts, :other_receive_3_title, :string
  end
end
