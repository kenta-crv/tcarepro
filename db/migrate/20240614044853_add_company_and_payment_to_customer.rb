class AddCompanyAndPaymentToCustomer < ActiveRecord::Migration[5.1]
  def change
    add_column :customers, :company_name, :string
    add_column :customers, :payment_date, :string
  end
end
