class CreateContracts < ActiveRecord::Migration[5.1]
  def change
    create_table :contracts do |t|
      t.string :company
      t.string :service
      t.string :search_1
      t.string :target_1
      t.string :search_2
      t.string :target_2
      t.string :search_3
      t.string :target_3
      t.string :slack_account
      t.string :slack_id
      t.string :slack_password
      t.string :area
      t.string :sales
      t.string :calender
      t.string :other
      t.timestamps
    end
  end
end
