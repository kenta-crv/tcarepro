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

    # Always use the most recently updated inquiry
    inquiry = Inquiry.order(updated_at: :desc).first
    unless inquiry
      error_message = "No Inquiry records found."
      Sidekiq.logger.error "AutoformSchedulerWorker: #{error_message}"
      contact_tracking.update(status: '自動送信エラー(データ無)')
      return
    end

    args = [
      "--url", contact_tracking.contact_url.to_s,
      "--unique_id", contact_tracking.id.to_s,
      "--session_code", contact_tracking.auto_job_code.to_s,
    ]
    args.concat(["--sender_id", contact_tracking.sender_id.to_s]) if contact_tracking.sender_id
    args.concat(["--worker_id", contact_tracking.worker_id.to_s]) if contact_tracking.worker_id

    args.concat(["--company", inquiry.from_company.to_s]) if inquiry.from_company.present?
    args.concat(["--company_kana", inquiry.from_company.to_s]) if inquiry.from_company.present?
    args.concat(["--manager", inquiry.person.to_s]) if inquiry.person.present?
    args.concat(["--manager_kana", inquiry.person_kana.to_s]) if inquiry.person_kana.present?
    args.concat(["--phone", inquiry.from_tel.to_s]) if inquiry.from_tel.present?
    args.concat(["--fax", inquiry.from_fax.to_s]) if inquiry.from_fax.present?
    args.concat(["--address", inquiry.address.to_s]) if inquiry.address.present?
    args.concat(["--zip", inquiry.zip_code.to_s]) if inquiry.respond_to?(:zip_code) && inquiry.zip_code.present?
    args.concat(["--mail", inquiry.from_mail.to_s]) if inquiry.from_mail.present?
    args.concat(["--url_on_form", inquiry.url.to_s]) if inquiry.url.present?
    args.concat(["--subjects", inquiry.title.to_s]) if inquiry.title.present?
    args.concat(["--body", inquiry.content.to_s]) if inquiry.content.present?

    unless PYTHON_EXECUTABLE && (File.exist?(PYTHON_EXECUTABLE) || system("which #{PYTHON_EXECUTABLE} > /dev/null 2>&1"))
      error_message = "Python executable '#{PYTHON_EXECUTABLE}' not found. Please check PYTHON_EXECUTABLE environment variable or system PATH."
      Sidekiq.logger.fatal "AutoformSchedulerWorker: #{error_message}"
      contact_tracking.update(status: '自動送信システムエラー(Py無)')
      return
    end

    command = [PYTHON_EXECUTABLE, PYTHON_SCRIPT_PATH] + args.map(&:to_s)
    Sidekiq.logger.info "AutoformSchedulerWorker: Executing command for CT ID #{contact_tracking_id}: #{command.join(' ')}"
    contact_tracking.update(status: '処理中')

    begin
      stdout, stderr, status = Open3.capture3(*command)
      Sidekiq.logger.info "AutoformSchedulerWorker: Python script STDOUT for CT ID #{contact_tracking_id}:\n#{stdout}" unless stdout.blank?
      Sidekiq.logger.error "AutoformSchedulerWorker: Python script STDERR for CT ID #{contact_tracking_id}:\n#{stderr}" unless stderr.blank?

      contact_tracking.reload
      current_status_after_script = contact_tracking.status

      if status.success?
        Sidekiq.logger.info "AutoformSchedulerWorker: Python script completed successfully for CT ID #{contact_tracking_id}. Final DB status: #{current_status_after_script}"
        if current_status_after_script == '処理中'
          Sidekiq.logger.warn "AutoformSchedulerWorker: Python script for CT ID #{contact_tracking_id} exited 0, but status remained '処理中'. Setting to '自動送信エラー(スクリプト未更新)'."
          contact_tracking.update(status: '自動送信エラー(スクリプト未更新)')
        end
      else
        Sidekiq.logger.error "AutoformSchedulerWorker: Python script execution failed for CT ID #{contact_tracking_id}. Exit status: #{status.exitstatus}. DB status before script failure: #{current_status_after_script}"
        if current_status_after_script == '処理中'
          Sidekiq.logger.error "AutoformSchedulerWorker: Python script for CT ID #{contact_tracking_id} failed and status is still '処理中'. Setting to '自動送信システムエラー(スクリプト失敗)'."
          contact_tracking.update(status: '自動送信システムエラー(スクリプト失敗)')
        end
      end

    rescue StandardError => e
      Sidekiq.logger.error "AutoformSchedulerWorker: Error executing Python script for CT ID #{contact_tracking_id}: #{e.message}"
      Sidekiq.logger.error e.backtrace.join("\n")
      contact_tracking.reload
      if contact_tracking.status == '処理中' || contact_tracking.status == '自動送信予定'
        contact_tracking.update(status: '自動送信システムエラー(ワーカー例外)')
      end
    end
  end
end