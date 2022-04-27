class ChangeCustomersGenre < ActiveRecord::Migration[5.1]
  def up
    change_table :customers do |t|
      t.change :genre, :string
    end
  end
  def down
    change_table :customers do |t|
      t.change :genre, :integer
    end
  end
end
