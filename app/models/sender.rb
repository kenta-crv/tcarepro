class Sender < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :counts
  has_many :contact_trackings

  def callback_url(customer_id)
    Rails.application.routes.url_helpers.callback_url(t: generate_code(customer_id))
  end

  def generate_code(customer_id)
    Digest::MD5.hexdigest({
      sender_id: id,
      customer_id: customer_id,
    }.to_json)
  end

  def send_contact!(customer_id, worker_id, inquiry_id, contact_url, status)
    contact_tracking = contact_trackings.find_or_initialize_by(
      code: generate_code(customer_id),
    )

    contact_tracking.attributes = {
      customer_id: customer_id,
      worker_id: worker_id,
      inquiry_id: inquiry_id,
      contact_url: contact_url,
      sended_at: status == '送信済' && Time.zone.now,
      status: status,
    }

    contact_tracking.save!
  end
end
