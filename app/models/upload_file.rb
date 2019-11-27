# == Schema Information
#
# Table name: upload_files
#
#  id         :integer          not null, primary key
#  name       :string
#  file       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class UploadFile < ApplicationRecord
	 mount_uploader :file, UploadFileUploader
	 validates :name, presence: true
end
