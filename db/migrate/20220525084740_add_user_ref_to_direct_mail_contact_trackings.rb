class AddUserRefToDirectMailContactTrackings < ActiveRecord::Migration[5.1]
  def change
    add_reference :direct_mail_contact_trackings, :user
  end
end
