class CreateKnowledges < ActiveRecord::Migration[5.1]
  def change
    create_table :knowledges do |t|
      t.string :title
      t.string :category
      t.string :genre
      t.string :file
      t.string :file_2
      t.string :priority
      t.string :body
      t.timestamps
    end
  end
end
