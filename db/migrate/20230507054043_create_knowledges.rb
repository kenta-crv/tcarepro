class CreateKnowledges < ActiveRecord::Migration[5.1]
  def change
    create_table :knowledges do |t|
      t.references :contract, foreign_key: true
      t.string :question
      t.string :genre
      t.string :answer
      t.timestamps
    end
  end
end
