class Image < ApplicationRecord
  belongs_to :crm
  mount_uploader :image, ImagesUploader
end
