require 'open3'

class AutoformSchedulerWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'default'

  PYTHON_SCRIPT_PATH = Rails.root.join('autoform', 'bootio.py').to_s
  PYTHON_VENV_PATH = Rails.root.join('autoform', 'venv', 'bin', 'python')
  PYTHON_EXECUTABLE = File.exist?(PYTHON_VENV_PATH) ? PYTHON_VENV_PATH.to_s : (ENV['PYTHON_EXECUTABLE'] || %w[python3 python].find { |cmd| system("which #{cmd} > /dev/null 2>&1") } || 'python')


  def perform(contact_tracking_id)
    contact_tracking = ContactTracking.find_by(id: contact_tracking_id)

    unless contact_tracking
      Sidekiq.logger.error "AutoformSchedulerWorker: ContactTracking with ID #{contact_tracking_id} not found."
      return
    end

    # Correctly fetch the associated Inquiry object
    # Assumes 'inquiry' is the association name in ContactTracking model
    inquiry = contact_tracking.inquiry 

    unless inquiry
      error_message = "Inquiry details not found for ContactTracking ID #{contact_tracking_id} (Inquiry ID: #{contact_tracking.inquiry_id})."
      Sidekiq.logger.error "AutoformSchedulerWorker: #{error_message}"
      contact_tracking.update(status: '自動送信エラー(Inquiry無)') # More specific error
      return
    end
    
    args = [
      "--url", contact_tracking.contact_url.to_s, # This is the URL of the contact form page itself
      "--unique_id", contact_tracking.id.to_s,
      "--session_code", contact_tracking.auto_job_code.to_s,
    ]

    args.concat(["--sender_id", contact_tracking.sender_id.to_s]) if contact_tracking.sender_id
    args.concat(["--worker_id", contact_tracking.worker_id.to_s]) if contact_tracking.worker_id

    # Map inquiry fields to bootio.py arguments, using schema names
    # Assuming Inquiry model attributes match schema (e.g., inquiry.from_company)
    args.concat(["--company", inquiry.from_company.to_s]) if inquiry.respond_to?(:from_company) && inquiry.from_company.present?
    args.concat(["--company_kana", inquiry.company_kana.to_s]) if inquiry.respond_to?(:company_kana) && inquiry.company_kana.present? # Not in schema, but keep if model has it
    
    # Manager Name (person in schema)
    if inquiry.respond_to?(:person) && inquiry.person.present?
        args.concat(["--manager", inquiry.person.to_s])
    # Fallback to split names if 'person' is not available but split names are
    elsif inquiry.respond_to?(:manager_last_name) && inquiry.respond_to?(:manager_first_name) 
        args.concat(["--manager_last", inquiry.manager_last_name.to_s]) if inquiry.manager_last_name.present?
        args.concat(["--manager_first", inquiry.manager_first_name.to_s]) if inquiry.manager_first_name.present?
    end

    # Manager Name Kana (person_kana in schema)
    if inquiry.respond_to?(:person_kana) && inquiry.person_kana.present?
        args.concat(["--manager_kana", inquiry.person_kana.to_s])
    # Fallback to split kana names
    elsif inquiry.respond_to?(:manager_last_name_kana) && inquiry.respond_to?(:manager_first_name_kana)
        args.concat(["--manager_last_kana", inquiry.manager_last_name_kana.to_s]) if inquiry.manager_last_name_kana.present?
        args.concat(["--manager_first_kana", inquiry.manager_first_name_kana.to_s]) if inquiry.manager_first_name_kana.present?
    end

    # Prefecture (assuming inquiry.prefecture is a specific field if available)
    args.concat(["--pref", inquiry.prefecture.to_s]) if inquiry.respond_to?(:prefecture) && inquiry.prefecture.present?

    # Phone Number (from_tel in schema)
    if inquiry.respond_to?(:from_tel) && inquiry.from_tel.present?
        args.concat(["--phone", inquiry.from_tel.to_s])
    # Fallback to split phone numbers
    elsif inquiry.respond_to?(:phone_number_1) # Assuming these are model attributes if from_tel isn't primary
        args.concat(["--phone0", inquiry.phone_number_1.to_s]) if inquiry.phone_number_1.present?
        args.concat(["--phone1", inquiry.phone_number_2.to_s]) if inquiry.respond_to?(:phone_number_2) && inquiry.phone_number_2.present?
        args.concat(["--phone2", inquiry.phone_number_3.to_s]) if inquiry.respond_to?(:phone_number_3) && inquiry.phone_number_3.present?
    end

    # Fax Number (from_fax in schema)
    args.concat(["--fax", inquiry.from_fax.to_s]) if inquiry.respond_to?(:from_fax) && inquiry.from_fax.present?
    
    # Address (address in schema)
    # Pass full address if available (assuming inquiry.address maps to inquiries.address)
    if inquiry.respond_to?(:address) && inquiry.address.present?
        args.concat(["--address", inquiry.address.to_s])
    # Fallback to split address parts if full address is not primary
    else
        args.concat(["--address_pref", inquiry.address_prefecture.to_s]) if inquiry.respond_to?(:address_prefecture) && inquiry.address_prefecture.present?
        args.concat(["--address_city", inquiry.address_city.to_s]) if inquiry.respond_to?(:address_city) && inquiry.address_city.present?
        args.concat(["--address_thin", inquiry.address_street.to_s]) if inquiry.respond_to?(:address_street) && inquiry.address_street.present?
    end
    
    # Zip Code (not in inquiries schema, but bootio.py supports it)
    args.concat(["--zip", inquiry.zip_code.to_s]) if inquiry.respond_to?(:zip_code) && inquiry.zip_code.present?
    
    # Email (from_mail in schema)
    args.concat(["--mail", inquiry.from_mail.to_s]) if inquiry.respond_to?(:from_mail) && inquiry.from_mail.present?
    
    # Website URL to fill in the form (url in inquiries schema)
    # Corrected argument name for bootio.py
    args.concat(["--url_on_form", inquiry.url.to_s]) if inquiry.respond_to?(:url) && inquiry.url.present?
    
    # Subject (title in inquiries schema)
    args.concat(["--subjects", inquiry.title.to_s]) if inquiry.respond_to?(:title) && inquiry.title.present?
    
    # Body (content in inquiries schema)
    args.concat(["--body", inquiry.content.to_s]) if inquiry.respond_to?(:content) && inquiry.content.present?

    unless PYTHON_EXECUTABLE && (File.exist?(PYTHON_EXECUTABLE) || system("which #{PYTHON_EXECUTABLE} > /dev/null 2>&1"))
        error_message = "Python executable '#{PYTHON_EXECUTABLE}' not found. Please check PYTHON_EXECUTABLE environment variable or system PATH."
        Sidekiq.logger.fatal "AutoformSchedulerWorker: #{error_message}"
        contact_tracking.update(status: '自動送信システムエラー(Py無)') # More specific error
        return
    end
    
    command = [PYTHON_EXECUTABLE, PYTHON_SCRIPT_PATH] + args.map(&:to_s)

    Sidekiq.logger.info "AutoformSchedulerWorker: Executing command for CT ID #{contact_tracking_id}: #{command.join(' ')}"
    
    contact_tracking.update(status: '処理中') # Mark as processing

    begin
      stdout, stderr, status = Open3.capture3(*command)

      Sidekiq.logger.info "AutoformSchedulerWorker: Python script STDOUT for CT ID #{contact_tracking_id}:\n#{stdout}" unless stdout.blank?
      Sidekiq.logger.error "AutoformSchedulerWorker: Python script STDERR for CT ID #{contact_tracking_id}:\n#{stderr}" unless stderr.blank?

      contact_tracking.reload # Reload to get the status potentially updated by bootio.py
      current_status_after_script = contact_tracking.status

      if status.success?
        Sidekiq.logger.info "AutoformSchedulerWorker: Python script completed successfully for CT ID #{contact_tracking_id}. Final DB status: #{current_status_after_script}"
        if current_status_after_script == '処理中'
            Sidekiq.logger.warn "AutoformSchedulerWorker: Python script for CT ID #{contact_tracking_id} exited 0, but status remained '処理中'. Setting to '自動送信エラー(スクリプト未更新)'."
            contact_tracking.update(status: '自動送信エラー(スクリプト未更新)')
        end
      else
        Sidekiq.logger.error "AutoformSchedulerWorker: Python script execution failed for CT ID #{contact_tracking_id}. Exit status: #{status.exitstatus}. DB status before script failure: #{current_status_after_script}"
        # If script failed, bootio.py should have set an error status.
        # If it's still '処理中', it means bootio.py crashed before updating the DB or failed to update.
        if current_status_after_script == '処理中'
          Sidekiq.logger.error "AutoformSchedulerWorker: Python script for CT ID #{contact_tracking_id} failed and status is still '処理中'. Setting to '自動送信システムエラー(スクリプト失敗)'."
          contact_tracking.update(status: '自動送信システムエラー(スクリプト失敗)')
        end
      end

    rescue StandardError => e
      Sidekiq.logger.error "AutoformSchedulerWorker: Error executing Python script for CT ID #{contact_tracking_id}: #{e.message}"
      Sidekiq.logger.error e.backtrace.join("\n")
      contact_tracking.reload # Reload before updating
      if contact_tracking.status == '処理中' || contact_tracking.status == '自動送信予定' # Check against original pre-processing status too
        contact_tracking.update(status: '自動送信システムエラー(ワーカー例外)')
      end
    end
  end
end