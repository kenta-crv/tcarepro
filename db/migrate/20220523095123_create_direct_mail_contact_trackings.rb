class CreateDirectMailContactTrackings < ActiveRecord::Migration[5.1]
  def change
    create_table :direct_mail_contact_trackings do |t|
      t.string :code, null: false, index: { unique: true }
      t.references :customer, null: false
      t.references :sender
      t.references :worker
      t.string :status, null: false
      t.string :contact_url
      t.datetime :sended_at
      t.datetime :callbacked_at
      t.timestamps
    end
  end
end
