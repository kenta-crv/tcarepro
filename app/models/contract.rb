class Contract < ApplicationRecord
  has_many :images, dependent: :destroy
  has_many :scripts, dependent: :destroy
end
