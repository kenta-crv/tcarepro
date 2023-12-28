class Contract < ApplicationRecord
  has_many :images
  has_many :knowledges
  #has_many :calls
end
