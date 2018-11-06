# == Schema Information
#
# Table name: companies
#
#  id                 :integer          not null, primary key
#  user_id            :integer
#  worker_id          :integer
#  company            :string
#  first_name         :string
#  last_name          :string
#  first_kana         :string
#  last_kana          :string
#  tel                :string
#  mobile             :string
#  fax                :string
#  e_mail             :string
#  postnumber         :string
#  prefecture         :string
#  city               :string
#  town               :string
#  caption            :string
#  labor_number       :string
#  employment_number  :string
#  trial_period       :string
#  work_start         :string
#  break_in           :string
#  break_out          :string
#  work_out           :string
#  holiday            :string
#  allowance          :string
#  allowance_contents :string
#  closing_on         :string
#  payment_on         :string
#  method_payment     :string
#  desuction          :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#

require 'test_helper'

class CompanyTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
