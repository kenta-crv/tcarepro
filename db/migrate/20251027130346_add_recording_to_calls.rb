class AddRecordingToCalls < ActiveRecord::Migration[5.1]
  def change
    add_column :calls, :recording_url, :string
    add_column :calls, :recording_duration, :integer
    add_column :calls, :recording_file_path, :string
    add_column :calls, :vapi_call_id, :string
    add_column :calls, :transcript, :text
    add_column :calls, :cost, :decimal
  end
end
