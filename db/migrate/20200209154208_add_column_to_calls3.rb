class AddColumnToCalls3 < ActiveRecord::Migration[5.1]
  def change
    add_column :calls, :customer_tel, :string
  end
end
