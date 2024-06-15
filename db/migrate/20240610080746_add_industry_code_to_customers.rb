class AddIndustryCodeToCustomers < ActiveRecord::Migration[5.1]
  def change
    add_column :customers, :industry_code, :integer
  end
end
