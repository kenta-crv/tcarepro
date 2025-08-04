class RemoveStartAddStartDatetimeToCustomers < ActiveRecord::Migration[5.1]
  def change
    add_column :customers, :next_date, :datetime
  end
end
