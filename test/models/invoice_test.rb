# == Schema Information
#
# Table name: invoices
#
#  id         :integer          not null, primary key
#  status     :string
#  deadline   :string
#  payment    :string
#  subject    :string
#  item1      :string
#  item2      :string
#  item3      :string
#  item4      :string
#  item5      :string
#  price1     :integer
#  price2     :integer
#  price3     :integer
#  price4     :integer
#  price5     :integer
#  quantity1  :integer
#  quantity2  :integer
#  quantity3  :integer
#  quantity4  :integer
#  quantity5  :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  company_id :integer
#

require 'test_helper'

class InvoiceTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
