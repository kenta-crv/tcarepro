class Image < ApplicationRecord
  belongs_to :contract
  mount_uploader :picture, ImagesUploader
end
