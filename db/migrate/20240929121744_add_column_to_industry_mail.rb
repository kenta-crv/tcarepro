class AddColumnToIndustryMail < ActiveRecord::Migration[5.1]
  def change
    add_column :customers, :industry_mail, :string
  end
end
