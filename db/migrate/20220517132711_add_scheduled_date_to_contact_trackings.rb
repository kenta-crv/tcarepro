class AddScheduledDateToContactTrackings < ActiveRecord::Migration[5.1]
  def change
    add_column :contact_trackings, :scheduled_date, :datetime
  end
end
