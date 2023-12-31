class AddTitleToScripts < ActiveRecord::Migration[5.1]
  def change
    add_column :scripts, :title, :string
  end
end
