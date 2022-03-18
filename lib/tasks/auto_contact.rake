require 'scraping'

namespace :auto_contact do
  desc 'お問い合わせページの確認'
  task check: :environment do
    scraping = Scraping.new

    Customer.limit(1000).each do |customer|
      contact = customer.attributes.compact.filter { |k, v| ['created_at', 'updated_at'].exclude?(k) }

      if customer.contact_url
        contact['contact_url'] = customer.contact_url

        contact['attributes'] = scraping.input_attributes(customer.contact_url)
      end

      config_path = Rails.root.join('auto_contact', 'config', 'customers')

      contact_url_missing_path = config_path.join('contact_url_missing', "#{customer.id}.yaml")
      attributes_missing_path = config_path.join('attributes_missing', "#{customer.id}.yaml")
      success_path = config_path.join('success', "#{customer.id}.yaml")

      [contact_url_missing_path, attributes_missing_path, success_path].each do |path|
        path.delete if path.exist?
      end

      if contact['contact_url']
        if contact['attributes']
          success_path.write(contact.to_yaml)
        else
          attributes_missing_path.write(contact.to_yaml)
        end
      else
        contact_url_missing_path.write(contact.to_yaml)
      end
    end
  end
end
