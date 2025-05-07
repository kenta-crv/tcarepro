class ChangeSenderIdNullOnSenderAssignments < ActiveRecord::Migration[5.1]
  def change
    change_column_null :sender_assignments, :sender_id, true
  end
end
