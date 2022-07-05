class AddCallbackUrlToContactTrackings < ActiveRecord::Migration[5.1]
  def change
    add_column :contact_trackings, :callback_url, :string
  end
end
