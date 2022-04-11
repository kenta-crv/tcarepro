class AddSenderColumnsToInquiries < ActiveRecord::Migration[5.1]
  def change
    change_column :senders, :rate_limit, :integer, default: nil
    add_reference :inquiries, :sender
    add_column :senders, :default_inquiry_id, :integer
  end
end
