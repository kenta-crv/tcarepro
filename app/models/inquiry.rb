require 'contactor'

class Inquiry < ApplicationRecord
  has_many :contact_trackings

  def generate_code(customer_id)
    Digest::MD5.hexdigest({
      customer_id: customer_id,
      inquiry_id: id,
    }.to_json)
  end

  def parse_content(customer_id)
    content.gsub('${callback_url}', callback_url(customer_id))
  end

  def callback_url(customer_id)
    Rails.application.routes.url_helpers.callback_url(t: generate_code(customer_id))
  end

  def contactor
    @contactor ||= Contactor.new(self)
  end
end
