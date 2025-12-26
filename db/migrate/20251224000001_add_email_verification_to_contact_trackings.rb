class AddEmailVerificationToContactTrackings < ActiveRecord::Migration[5.1]
  def change
    add_column :contact_trackings, :email_received, :boolean, default: false, null: false
    add_column :contact_trackings, :email_received_at, :datetime
    add_column :contact_trackings, :email_subject, :string
    add_column :contact_trackings, :email_from, :string
    add_column :contact_trackings, :email_matched_at, :datetime
    
    add_index :contact_trackings, :email_received
    add_index :contact_trackings, :email_received_at
  end
end

