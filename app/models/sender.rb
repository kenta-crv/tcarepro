require 'uri'
require 'net/http'

class Sender < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  belongs_to :default_inquiry, foreign_key: :default_inquiry_id, class_name: 'Inquiry', optional: true

  has_many :counts
  has_many :contact_trackings
  has_many :customers
  has_many :inquiries
  has_many :direct_mail_contact_trackings

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

  def send_direct_mail_contact!(customer_id, user_id,worker_id)
    code = generate_code
    direct_mail_contact_tracking = direct_mail_contact_trackings.new(
      code: code,
      customer_id: customer_id,
      user_id: user_id,
      worker_id: worker_id,
      sended_at: Time.zone.now,
      status: '送信済',
    )

    direct_mail_contact_tracking.save!
    Rails.application.routes.url_helpers.direct_mail_callback_url(t: code)
  end

  def auto_send_contact!(code, customer_id, worker_id, inquiry_id, date,contact_url, status, customers_code,reserve_code,generation_code)
    code = generate_code
    #API送信SSS
    contact_tracking = contact_trackings.new(
      code: code,
      customer_id: customer_id,
      worker_id: worker_id,
      inquiry_id: inquiry_id,
      contact_url: contact_url,
      scheduled_date: date,
      callback_url: callback_url(code),
      sended_at: status == '送信済' && Time.zone.now,
      status: status,
      customers_code: customers_code,
      auto_job_code: generation_code,
    )

    contact_tracking.save!
  end
end
