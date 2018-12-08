class RemoveTelFromDetails < ActiveRecord::Migration[5.1]
  def change
    remove_column :details, :tel, :integer
  end
end
