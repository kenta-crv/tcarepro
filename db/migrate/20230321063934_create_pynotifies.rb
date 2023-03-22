class CreatePynotifies < ActiveRecord::Migration[5.1]
  def change
    create_table :pynotifies do |t|
      t.string :title
      t.string :message
      t.string :status
      t.timestamps 
    end
  end
end
