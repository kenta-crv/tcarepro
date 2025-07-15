require 'uri'
require 'net/http'

class Sender < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  belongs_to :default_inquiry, foreign_key: :default_inquiry_id, class_name: 'Inquiry', optional: true

  has_many :counts
  has_many :sender_assignments, dependent: :destroy
  has_many :workers, through: :sender_assignments
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
    customer = Customer.find(customer_id)
    customer.skip_validation = true  # ← これを追加！
    # contact_urlが異なるときだけ強制的に更新（バリデーション無視）
    if contact_url.present? && customer.contact_url != contact_url
      customer.update_column(:contact_url, contact_url)
    end
  
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

  def auto_send_contact!(code, customer_id, worker_id, inquiry_id, date,contact_url, status, customers_code)
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
      auto_job_code: generate_code,
    )

    contact_tracking.save!
  end

  def default_inquiry_id
    # Example: if you have a direct association or a setting
    # self.primary_inquiry_id 
    # Or if you have a default_inquiry association:
    # self.default_inquiry&.id
    # For now, ensure this returns an Integer ID.
    # Replace with your actual logic. If it's an attribute, no method needed.
    # If it's an association `belongs_to :default_inquiry, class_name: 'Inquiry'`, then use default_inquiry.id
    # This is a placeholder, update with your logic:
    Inquiry.first&.id # !!! Replace this with your actual logic for default inquiry ID
  end

  # Used by the worker to generate a unique code for each tracking attempt
  def generate_code
    # Example: SecureRandom.hex(10) or a more structured code
    "gen_#{Time.now.to_i}_#{SecureRandom.hex(6)}"
  end

  # Used by the worker to set the callback URL on ContactTracking
  # This URL is where Python *would* call back if it were to report on individual submission attempts.
  # Note: Your current Python /api/v1/rocketbumb just acknowledges scheduling.
  # If Python's actual form submission part later needs to call back to Rails with success/failure
  # for a *specific generation_code*, this URL would be used.
  def callback_url(generation_code)
    # Example: using Rails URL helpers. Ensure you have a route for this.
    # Rails.application.routes.url_helpers.api_v1_submission_update_url(host: ENV['APP_BASE_URL'], code: generation_code)
    # For now, a placeholder structure:
    "#{ENV.fetch('APP_BASE_URL', 'http://localhost:3000')}/callbacks/autoform/#{generation_code}"
  end
end
