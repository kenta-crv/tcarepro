class AddColumnPynotify < ActiveRecord::Migration[5.1]
  def change
    add_column :pynotifies, :sended_at, :datetime
  end
end
