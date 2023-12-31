class Contract < ApplicationRecord
  has_many :images
  has_many :scripts
  #has_many :calls
end
