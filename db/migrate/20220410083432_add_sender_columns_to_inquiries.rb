class AddSenderColumnsToInquiries < ActiveRecord::Migration[5.1]
  def change
    add_reference :inquiries, :sender
    add_column :senders, :default_inquiry_id, :integer
  end
end
