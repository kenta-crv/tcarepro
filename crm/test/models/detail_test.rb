# == Schema Information
#
# Table name: details
#
#  id            :integer          not null, primary key
#  name          :string
#  product_type  :string
#  method        :string
#  tel           :integer
#  post          :string
#  address       :string
#  point         :string
#  prefecture_id :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#

require 'test_helper'

class DetailTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
