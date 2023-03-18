class AddCustomerscodeToCustomers < ActiveRecord::Migration[5.1]
  def change
    add_column :customers, :customers_code, :string
  end
end
