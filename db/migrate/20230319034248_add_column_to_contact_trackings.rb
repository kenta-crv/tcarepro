class AddColumnToContactTrackings < ActiveRecord::Migration[5.1]
  def change
    add_column :contact_trackings, :auto_job_code, :string
  end
end
