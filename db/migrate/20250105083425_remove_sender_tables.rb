class RemoveSenderTables < ActiveRecord::Migration[5.1]
  def up
    # Remove sender assignments table
    # drop_table :sender_assignments if table_exists?(:sender_assignments)
    
    # # Remove senders table
    # drop_table :senders if table_exists?(:senders)
    
    # # Remove sender_id columns from other tables
    # remove_column :contact_trackings, :sender_id if column_exists?(:contact_trackings, :sender_id)
    # remove_column :counts, :sender_id if column_exists?(:counts, :sender_id)
    # remove_column :direct_mail_contact_trackings, :sender_id if column_exists?(:direct_mail_contact_trackings, :sender_id)
    # remove_column :inquiries, :sender_id if column_exists?(:inquiries, :sender_id)
    # remove_column :autoform_results, :sender_id if column_exists?(:autoform_results, :sender_id)
    
    # # Remove indexes
    # remove_index :contact_trackings, name: :index_contact_trackings_on_sender_id if index_exists?(:contact_trackings, :sender_id)
    # remove_index :counts, name: :index_counts_on_sender_id if index_exists?(:counts, :sender_id)
    # remove_index :direct_mail_contact_trackings, name: :index_direct_mail_contact_trackings_on_sender_id if index_exists?(:direct_mail_contact_trackings, :sender_id)
    # remove_index :inquiries, name: :index_inquiries_on_sender_id if index_exists?(:inquiries, :sender_id)
  end

  def down
    # This migration is not reversible
    raise ActiveRecord::IrreversibleMigration
  end
end 