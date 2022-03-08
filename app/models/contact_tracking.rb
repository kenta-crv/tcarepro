class ContactTracking < ApplicationRecord
  belongs_to :customer
  belongs_to :inquiry
  belongs_to :sender, optional: true
  belongs_to :worker, optional: true

  validates :code, uniqueness: true, presence: true

  def try_typings
    inquiry.contactor.try_typings(contact_url || customer.url || customer.url_2, customer.id)
  end
end
