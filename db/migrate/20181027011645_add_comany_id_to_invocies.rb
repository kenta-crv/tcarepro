class AddComanyIdToInvocies < ActiveRecord::Migration[5.1]
  def change
    add_column :invoices, :company_id, :integer
  end
end
