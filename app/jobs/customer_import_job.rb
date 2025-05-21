class CustomerImportJob < ApplicationJob
  queue_as :default


  def perform(file_path, options = {})
  skip_repurpose = options['skip_repurpose'] == true

  file = File.open(file_path)
  Customer.all_import(file, skip_repurpose: skip_repurpose)
  file.close
  File.delete(file_path) if File.exist?(file_path)
end
end
