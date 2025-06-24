class CreateAccessLogs < ActiveRecord::Migration[5.1]
  def change
    create_table :access_logs do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :path
      t.string :ip
      t.datetime :accessed_at

      t.timestamps
    end
  end
end
