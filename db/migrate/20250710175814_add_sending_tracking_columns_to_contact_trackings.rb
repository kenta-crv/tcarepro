class AddSendingTrackingColumnsToContactTrackings < ActiveRecord::Migration[5.1]
  def change
    add_column :contact_trackings, :sending_started_at, :datetime
    add_column :contact_trackings, :sending_completed_at, :datetime
    add_column :contact_trackings, :response_data, :text
  end
end