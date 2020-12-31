class Matter < ApplicationRecord
  belongs_to :admin, optional: true
  belongs_to :member, optional: true
end
