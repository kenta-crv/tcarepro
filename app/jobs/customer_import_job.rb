class CustomerImportJob < ApplicationJob
  queue_as :default

  def perform(file_path)
    File.open(file_path) do |file|
      Customer.all_import(file)
    end

    File.delete(file_path) if File.exist?(file_path)
  end
  #def perform(file_path, options = {})
  #skip_repurpose = options['skip_repurpose'] == true

  #file = File.open(file_path)
  #Customer.all_import(file, skip_repurpose: skip_repurpose)
  #file.close
  #File.delete(file_path) if File.exist?(file_path)
  #end
end
