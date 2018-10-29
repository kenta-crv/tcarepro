# == Schema Information
#
# Table name: upload_data
#
#  id         :integer          not null, primary key
#  name       :string
#  file       :string
#  company_id :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class UploadDatum < ApplicationRecord
  belongs_to :company
end
