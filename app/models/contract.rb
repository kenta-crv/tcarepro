class Contract < ApplicationRecord
  has_many :images
  has_many :knowledges
  belongs_to :customer
  has_many :calls

  serialize :search, JSON
  serialize :target, JSON
end
