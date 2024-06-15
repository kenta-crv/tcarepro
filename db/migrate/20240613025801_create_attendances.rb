class CreateAttendances < ActiveRecord::Migration[5.1]
  def change
    create_table :attendances do |t|
      t.references :user, foreign_key: true
      t.integer :month
      t.integer :year
      t.float :hours_worked
      t.timestamps
    end
  end
end
