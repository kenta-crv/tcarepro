require 'contactor'

class Inquiry < ApplicationRecord
  has_many :contact_trackings

  def parse_content(sender, customer_id)
    content.gsub('${callback_url}', sender.callback_url(customer_id))
  end
end
