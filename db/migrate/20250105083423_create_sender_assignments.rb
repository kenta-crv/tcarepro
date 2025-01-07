class CreateSenderAssignments < ActiveRecord::Migration[5.1]
  def change
    create_table :sender_assignments do |t|
      t.references :worker, null: false, foreign_key: true
      t.references :sender, null: false, foreign_key: true
      t.timestamps
    end
  end
end
