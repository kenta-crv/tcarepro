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

require 'test_helper'

class UploadDatumTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
