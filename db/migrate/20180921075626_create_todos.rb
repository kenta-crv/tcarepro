class CreateTodos < ActiveRecord::Migration[5.1]
  def change
    create_table :todos do |t|
      t.string :execution
      t.string :title
      t.string :select
      t.string :deadline
      t.string :state
      t.string :name
      t.string :contents

      t.timestamps
    end
  end
end
