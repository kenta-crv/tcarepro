# == Schema Information
#
# Table name: faqs
#
#  id         :integer          not null, primary key
#  title      :string
#  select     :string
#  contents   :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class Faq < ApplicationRecord
end
