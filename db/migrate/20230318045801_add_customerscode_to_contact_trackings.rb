class AddCustomerscodeToContactTrackings < ActiveRecord::Migration[5.1]
  def change
    add_column :contact_trackings, :customers_code, :string
  end
end
