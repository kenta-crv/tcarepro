class AddColumnToCustomerGenre < ActiveRecord::Migration[5.1]
  def change
    add_column :customers, :genre, :integer
  end
end
