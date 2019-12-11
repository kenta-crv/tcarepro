class Crm < ApplicationRecord
  has_many :acquisitions
  has_many :comments
  has_many :images
  has_many :faqs
  has_many :images
  has_many :invoices
end
