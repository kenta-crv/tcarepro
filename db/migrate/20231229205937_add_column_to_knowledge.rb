class AddColumnToKnowledge < ActiveRecord::Migration[5.1]
  def change
    add_column :knowledges, :name_1, :string
    add_column :knowledges, :name_2, :string
    add_column :knowledges, :name_3, :string
    add_column :knowledges, :url_1, :string
    add_column :knowledges, :url_2, :string
    add_column :knowledges, :url_3, :string
  end
end
