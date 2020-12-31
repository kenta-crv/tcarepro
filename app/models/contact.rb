class Contact < ApplicationRecord
  validates :company, {presence: true}
  validates :name, {presence: true}
  validates :tel, {presence: true}
  validates :address, {presence: true}
  validates :email, {presence: true}
  validates :subject, {presence: true}
  validates :message, {presence: true}
end
