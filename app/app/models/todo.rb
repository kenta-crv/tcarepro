# == Schema Information
#
# Table name: todos
#
#  id         :integer          not null, primary key
#  execution  :string
#  title      :string
#  select     :string
#  deadline   :string
#  state      :string
#  name       :string
#  contents   :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class Todo < ApplicationRecord
end
