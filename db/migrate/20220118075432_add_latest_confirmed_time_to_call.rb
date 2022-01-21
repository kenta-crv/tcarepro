class AddLatestConfirmedTimeToCall < ActiveRecord::Migration[5.1]
  def change
    add_column :calls, :latest_confirmed_time, :datetime
    Call.where('time is not null').update_all(latest_confirmed_time: Time.zone.now - 3.day)
    add_index :calls, [:user_id, :latest_confirmed_time, :time]
  end
end
