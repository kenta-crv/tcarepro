class CreateContacts < ActiveRecord::Migration[5.1]
  def change
    create_table :contacts do |t|
      t.references :worker, foreign_key: true
      t.string :question
      t.string :body
      t.timestamps
    end
  end
end
