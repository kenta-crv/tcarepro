class NameMapping < ActiveHash::Base
  include Rails.application.routes.url_helpers

  self.data = YAML.load_file(Rails.root.join('config', 'name_mappings.yml'))

  def self.find_key(name, label)
    NameMapping.all.find do |name_mapping|
      name_mapping.input_names.any? do |input_name|
        input_name == name || label =~ Regexp.new(input_name)
      end
    end
  end
end
