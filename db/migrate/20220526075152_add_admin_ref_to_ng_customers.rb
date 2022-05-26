class AddAdminRefToNgCustomers < ActiveRecord::Migration[5.1]
  def change
    add_reference :ng_customers, :admin
  end
end
