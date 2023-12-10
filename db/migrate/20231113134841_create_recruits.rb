class CreateRecruits < ActiveRecord::Migration[5.1]
  def change
    create_table :recruits do |t|
      t.string :name 
      t.string :age
      t.string :email
      t.string :experience
      t.string :voice_data

      t.string :year
      t.string :commodity
      t.string :hope
      t.string :period
      t.string :pc
      t.string :start
      t.text :encoded_voice_data
      t.timestamps
    end
  end
end
