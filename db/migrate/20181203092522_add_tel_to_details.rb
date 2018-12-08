class AddTelToDetails < ActiveRecord::Migration[5.1]
  def change
    add_column :details, :tel, :string
  end
end
