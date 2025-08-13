class CustomerImportJob < ApplicationJob
  queue_as :default

  def perform(file_path, options = {})
    skip_repurpose = options['skip_repurpose'] == true || options['skip_repurpose'] == "1"

    File.open(file_path) do |file|
      Customer.all_import(file, skip_repurpose: skip_repurpose)
    end

    File.delete(file_path) if File.exist?(file_path)
  end
end
