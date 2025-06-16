require 'open3'

class AutoformSchedulerWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'default'

  PYTHON_SCRIPT_PATH = Rails.root.join('autoform', 'bootio.py').to_s
  PYTHON_VENV_PATH = Rails.root.join('autoform/autoform', 'bin', 'python')
  PYTHON_EXECUTABLE = File.exist?(PYTHON_VENV_PATH) ? PYTHON_VENV_PATH.to_s : (ENV['PYTHON_EXECUTABLE'] || %w[python3 python].find { |cmd| system("which #{cmd} > /dev/null 2>&1") } || 'python')


  def perform(contact_tracking_id)
    Sidekiq.logger.error "!!!!!! AutoformSchedulerWorker (using Sidekiq.logger): PERFORM METHOD ENTERED with CT ID: #{contact_tracking_id} !!!!!!"
    Rails.logger.error "!!!!!! AutoformSchedulerWorker (using Rails.logger): PERFORM METHOD ENTERED with CT ID: #{contact_tracking_id} !!!!!!"
    contact_tracking = ContactTracking.find_by(id: contact_tracking_id)

    unless contact_tracking
      Rails.logger.error "AutoformSchedulerWorker: ContactTracking with ID #{contact_tracking_id} not found."
      return
    end

    inquiry = contact_tracking.inquiry

    unless inquiry
      error_message = "Inquiry details not found for ContactTracking ID #{contact_tracking_id}."
      Rails.logger.error "AutoformSchedulerWorker: #{error_message}"
      contact_tracking.update(status: '自動送信エラー')
      return
    end
    
    args = [
      "--url", contact_tracking.contact_url.to_s,
      "--unique_id", contact_tracking.id.to_s,
      "--session_code", contact_tracking.auto_job_code.to_s,
    ]

    args.concat(["--sender_id", contact_tracking.sender_id.to_s]) if contact_tracking.sender_id
    args.concat(["--worker_id", contact_tracking.worker_id.to_s]) if contact_tracking.worker_id

    args.concat(["--company", inquiry.company_name.to_s]) if inquiry.respond_to?(:company_name)
    args.concat(["--company_kana", inquiry.company_kana.to_s]) if inquiry.respond_to?(:company_kana)
    
    if inquiry.respond_to?(:manager_full_name) && inquiry.manager_full_name.present?
        args.concat(["--manager", inquiry.manager_full_name.to_s])
    elsif inquiry.respond_to?(:manager_last_name) && inquiry.respond_to?(:manager_first_name)
        args.concat(["--manager_last", inquiry.manager_last_name.to_s]) if inquiry.manager_last_name.present?
        args.concat(["--manager_first", inquiry.manager_first_name.to_s]) if inquiry.manager_first_name.present?
    end

    if inquiry.respond_to?(:manager_full_name_kana) && inquiry.manager_full_name_kana.present?
        args.concat(["--manager_kana", inquiry.manager_full_name_kana.to_s])
    elsif inquiry.respond_to?(:manager_last_name_kana) && inquiry.respond_to?(:manager_first_name_kana)
        args.concat(["--manager_last_kana", inquiry.manager_last_name_kana.to_s]) if inquiry.manager_last_name_kana.present?
        args.concat(["--manager_first_kana", inquiry.manager_first_name_kana.to_s]) if inquiry.manager_first_name_kana.present?
    end

    args.concat(["--pref", inquiry.prefecture.to_s]) if inquiry.respond_to?(:prefecture)

    if inquiry.respond_to?(:phone_number) && inquiry.phone_number.present?
        args.concat(["--phone", inquiry.phone_number.to_s])
    elsif inquiry.respond_to?(:phone_number_1)
        args.concat(["--phone0", inquiry.phone_number_1.to_s]) if inquiry.phone_number_1.present?
        args.concat(["--phone1", inquiry.phone_number_2.to_s]) if inquiry.respond_to?(:phone_number_2) && inquiry.phone_number_2.present?
        args.concat(["--phone2", inquiry.phone_number_3.to_s]) if inquiry.respond_to?(:phone_number_3) && inquiry.phone_number_3.present?
    end

    args.concat(["--fax", inquiry.fax_number.to_s]) if inquiry.respond_to?(:fax_number) && inquiry.fax_number.present?
    
    if inquiry.respond_to?(:full_address) && inquiry.full_address.present?
        args.concat(["--address", inquiry.full_address.to_s])
    else
        args.concat(["--address_pref", inquiry.address_prefecture.to_s]) if inquiry.respond_to?(:address_prefecture) && inquiry.address_prefecture.present?
        args.concat(["--address_city", inquiry.address_city.to_s]) if inquiry.respond_to?(:address_city) && inquiry.address_city.present?
        args.concat(["--address_thin", inquiry.address_street.to_s]) if inquiry.respond_to?(:address_street) && inquiry.address_street.present?
    end
    
    args.concat(["--zip", inquiry.zip_code.to_s]) if inquiry.respond_to?(:zip_code) && inquiry.zip_code.present?
    args.concat(["--mail", inquiry.email.to_s]) if inquiry.respond_to?(:email) && inquiry.email.present?
    args.concat(["--form_url", inquiry.website_url.to_s]) if inquiry.respond_to?(:website_url) && inquiry.website_url.present?
    args.concat(["--subjects", inquiry.subject.to_s]) if inquiry.respond_to?(:subject) && inquiry.subject.present?
    args.concat(["--body", inquiry.body_content.to_s]) if inquiry.respond_to?(:body_content) && inquiry.body_content.present?

    # Ensure PYTHON_EXECUTABLE is found
    unless PYTHON_EXECUTABLE && File.exist?(PYTHON_EXECUTABLE) || system("which #{PYTHON_EXECUTABLE} > /dev/null 2>&1")
        error_message = "Python executable '#{PYTHON_EXECUTABLE}' not found. Please check PYTHON_EXECUTABLE environment variable or system PATH."
        Rails.logger.fatal "AutoformSchedulerWorker: #{error_message}"
        contact_tracking.update(status: '自動送信システムエラー')
        # Potentially raise an error to stop retries if this is a system config issue
        # raise StandardError, error_message 
        return
    end
    
    command = [PYTHON_EXECUTABLE, PYTHON_SCRIPT_PATH] + args.map(&:to_s) # Ensure all args are strings

    Rails.logger.info "AutoformSchedulerWorker: Executing command for CT ID #{contact_tracking_id}: #{command.join(' ')}"
    
    # Mark as processing before calling script
    contact_tracking.update(status: '処理中')


    begin
      stdout, stderr, status = Open3.capture3(*command)

      Rails.logger.info "AutoformSchedulerWorker: Python script STDOUT for CT ID #{contact_tracking_id}:\n#{stdout}"
      unless stderr.blank?
        Rails.logger.error "AutoformSchedulerWorker: Python script STDERR for CT ID #{contact_tracking_id}:\n#{stderr}"
      end

      contact_tracking.reload
      current_status_after_script = contact_tracking.status
      # current_notes_after_script = contact_tracking.notes

      if status.success?
        Rails.logger.info "AutoformSchedulerWorker: Python script completed for CT ID #{contact_tracking_id}. Final DB status: #{current_status_after_script}"
        # If script ran but didn't update status from '処理中', it might be an internal script logic issue
        if current_status_after_script == '処理中'
            contact_tracking.update(status: '自動送信エラー')
        end
      else
        Rails.logger.error "AutoformSchedulerWorker: Python script execution failed for CT ID #{contact_tracking_id}. Exit status: #{status.exitstatus}. Final DB status: #{current_status_after_script}"
        # If script failed and status is still '処理中', it means script crashed before updating DB or failed to update.
        if current_status_after_script == '処理中'
          contact_tracking.update(status: '自動送信システムエラー')
        end
      end

    rescue StandardError => e
      Rails.logger.error "AutoformSchedulerWorker: Error executing Python script for CT ID #{contact_tracking_id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Ensure status is updated if an exception occurs in Ruby before/during script call
      contact_tracking.reload
      if contact_tracking.status == '処理中' || contact_tracking.status == '自動送信予定'
        contact_tracking.update(status: '自動送信システムエラー')
      end
    end
  end
end