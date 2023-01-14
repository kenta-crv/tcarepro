class Contract < ApplicationRecord
  has_many :images
  mount_uploader :image, ImagesUploader
end
