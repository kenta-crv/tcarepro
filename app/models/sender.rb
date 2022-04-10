class Sender < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  belongs_to :default_inquiry, foreign_key: :default_inquiry_id, class_name: 'Inquiry', optional: true

  has_many :counts
  has_many :contact_trackings
  has_many :inquiries

  def callback_url(code)
    Rails.application.routes.url_helpers.callback_url(t: code)
  end

  def generate_code
    SecureRandom.hex
  end

  def send_contact!(code, customer_id, worker_id, inquiry_id, contact_url, status)
    contact_tracking = contact_trackings.new(
      code: code,
      customer_id: customer_id,
      worker_id: worker_id,
      inquiry_id: inquiry_id,
      contact_url: contact_url,
      sended_at: status == '送信済' && Time.zone.now,
      status: status,
    )

    contact_tracking.save!
  end
end
