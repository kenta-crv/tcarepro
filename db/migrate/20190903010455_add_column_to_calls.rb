class AddColumnToCalls < ActiveRecord::Migration[5.1]
  def change
    add_reference :calls, :admin, foreign_key: true
  end
end
