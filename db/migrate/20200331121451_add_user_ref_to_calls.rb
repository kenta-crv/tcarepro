class AddUserRefToCalls < ActiveRecord::Migration[5.1]
  def change
    add_reference :calls, :user, foreign_key: true
  end
end
