class CreateSkillsheets < ActiveRecord::Migration[5.1]
  def change
    create_table :skillsheets do |t|
      t.string :name
      t.string :tel
      t.string :mail
      t.string :address
      t.string :age
      t.string :start
      t.string :experience
      t.string :history
      t.string :title
      t.timestamps
    end
  end
end
