class CreateContactTrackings < ActiveRecord::Migration[5.1]
  def change
    create_table :contact_trackings do |t|
      t.string :code, null: false, index: { unique: true }
      t.references :customer, null: false
      t.references :inquiry, null: false
      t.references :sender
      t.references :worker
      t.string :status, null: false
      t.string :contact_url
      t.datetime :sended_at
      t.datetime :callbacked_at

      t.timestamps
    end

    add_index :contact_trackings, [:customer_id, :inquiry_id, :sender_id, :worker_id], name: :index_contact_trackings_on_colums

    add_column :senders, :rate_limit, :integer, default: 100
  end
end
