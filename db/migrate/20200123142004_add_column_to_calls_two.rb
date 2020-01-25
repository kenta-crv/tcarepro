class AddColumnToCallsTwo < ActiveRecord::Migration[5.1]
  def change
    add_reference :calls, :crm, foreign_key: true
  end
end
