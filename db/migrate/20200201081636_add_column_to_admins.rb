class AddColumnToAdmins < ActiveRecord::Migration[5.1]
  def change
    add_column :admins, :select, :string
  end
end
