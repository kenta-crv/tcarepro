class CreateKnowledges < ActiveRecord::Migration[5.1]
  def change
    create_table :knowledges do |t|
      t.string :title
      t.string :select
      t.string :name
      t.string :answer
      t.timestamps
    end
  end
end
