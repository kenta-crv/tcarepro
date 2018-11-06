# == Schema Information
#
# Table name: prefectures
#
#  id           :integer          not null, primary key
#  labor        :string
#  product_type :string
#  method       :string
#  tel          :integer
#  post         :string
#  address      :string
#  point        :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#

require 'test_helper'

class PrefectureTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
