class DirectMailContactTracking < ApplicationRecord
  belongs_to :sender, optional: true
  belongs_to :customer, optional: true
  belongs_to :user, optional: true
  belongs_to :worker, optional: true

  validates :code, uniqueness: true, presence: true
  validates :status, presence: true, inclusion: { in: %w(送信済 送信不可 営業NG) }

  scope :latest, ->(sender_id){
    where(id: ContactTracking.select('max(id) as id').where(sender_id: sender_id).group(:customer_id))
  }

  before_validation :set_code

  def callback_url
    Rails.application.routes.url_helpers.direct_mail_callback_url(t: code)
  end

  def generate_code
    SecureRandom.hex
  end

  def success?
    status == '送信済'
  end

  private

  def set_code
    self.code = generate_code
  end
end
