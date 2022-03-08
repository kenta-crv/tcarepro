require 'scraping'
require 'contactor'

def config_root
  Rails.root.join('auto_contact', 'config', 'customers')
end

def contact_url_missing_path(customer_id)
  config_root.join('contact_url_missing', "#{customer_id}.yaml")
end

def attributes_missing_path(customer_id)
  config_root.join('attributes_missing', "#{customer_id}.yaml")
end

def success_path(customer_id)
  config_root.join('success', "#{customer_id}.yaml")
end

namespace :auto_contact do
  desc 'お問い合わせページの確認'
  task :check, ['customer_id'] => :environment do |task, args|
    scraping = Scraping.new

    customers = args['customer_id'] ? Customer.where(id: args['customer_id']) : Customer.limit(100)

    customers.each do |customer|
      contact = customer.attributes.compact.filter { |k, v| ['created_at', 'updated_at'].exclude?(k) }

      if customer.contact_url
        contact['contact_url'] = customer.contact_url

        contact['attributes'] = scraping.input_attributes(customer.contact_url)
      end

      [contact_url_missing_path(contact['id']), attributes_missing_path(contact['id']), success_path(contact['id'])].each do |path|
        path.delete if path.exist?
      end

      if contact['contact_url']
        if contact['attributes'].present?
          success_path(contact['id']).write(contact.to_yaml)
        else
          attributes_missing_path(contact['id']).write(contact.to_yaml)
        end
      else
        contact_url_missing_path(contact['id']).write(contact.to_yaml)
      end
    end
  end

  task :run, ['customer_id'] => :environment do |task, args|
    config = Rails.root.join('auto_contact', 'config', 'customers', 'success')

    inquiry = Inquiry.first

    config.glob("#{args['customer_id'].presence || '*'}.yaml").sort.each do |yaml|
      contact = YAML.load_file(yaml)

      puts "customer_id: #{contact['id']}"

      inquiry.generate_code(contact['id'])

      contact_tracking = ContactTracking.find_or_initialize_by(
        code: inquiry.generate_code(contact['id']),
      )

      contact_tracking.attributes = {
        customer: Customer.find(contact['id']),
        inquiry: inquiry,
        contact_url: contact['contact_url'],
      }

      inquiry.contactor.send_contact(contact_tracking.contact_url, contact['id'])

      screenshot_path = Rails.root.join('auto_contact', 'screenshots', "#{contact['id']}.png")
      inquiry.contactor.screenshot(screenshot_path)

      contact_tracking.save!
    end
  end
end
