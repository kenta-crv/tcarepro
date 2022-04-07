class ContactTracking < ApplicationRecord
  belongs_to :sender
  belongs_to :customer
  belongs_to :inquiry
  belongs_to :worker, optional: true

  validates :code, uniqueness: true, presence: true
  validates :status, presence: true, inclusion: { in: %w(送信済 送信不可 送信NG) }

  def success?
    status == '送信済'
  end
end
