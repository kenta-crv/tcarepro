class Contract < ApplicationRecord
  has_many :scripts, dependent: :destroy
end
