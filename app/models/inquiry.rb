require 'contactor'

class Inquiry < ApplicationRecord
  has_many :contact_trackings

  validates :headline, presence: true
  validates :url, presence: true
  validates :content, presence: true, format: { with: /\${callback_url}/ }

  def parse_content(sender, code)
    content.gsub('${callback_url}', sender.callback_url(code))
  end
end
