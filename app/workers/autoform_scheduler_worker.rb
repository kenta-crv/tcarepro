require 'open3'

class AutoformSchedulerWorker
  include Sidekiq::Worker
  # 大量送信の耐久・耐性を確保
  sidekiq_options retry: 3, queue: 'default', backtrace: true

  PYTHON_SCRIPT_PATH = Rails.root.join('autoform', 'bootio.py').to_s
  PYTHON_VENV_PATH = Rails.root.join('autoform', 'venv', 'bin', 'python')
  # 一旦退避
  # PYTHON_EXECUTABLE = File.exist?(PYTHON_VENV_PATH) ? PYTHON_VENV_PATH.to_s : (ENV['PYTHON_EXECUTABLE'] || %w[python3 python].find { |cmd| system("which #{cmd} > /dev/null 2>&1") } || 'python')
  PYTHON_EXECUTABLE = 'python3'  # システムのpython3を強制使用


  def perform(contact_tracking_id)
    contact_tracking = ContactTracking.find_by(id: contact_tracking_id)
    unless contact_tracking
      Sidekiq.logger.error "AutoformSchedulerWorker: ContactTracking with ID #{contact_tracking_id} not found."
      return
    end

    # 送信開始状態の記録
    contact_tracking.update!(
      status: '送信中',
      sending_started_at: Time.current
    )

    # URL自動検索機能
    if contact_tracking.contact_url.blank?
      Sidekiq.logger.info "AutoformSchedulerWorker: contact_url is blank for CT ID #{contact_tracking_id}, attempting auto-search"
      # URLを自動取得するロジックをここに追加
      auto_url = search_contact_url_automatically(contact_tracking)
      if auto_url.present?
        contact_tracking.update(contact_url: auto_url)
        Sidekiq.logger.info "AutoformSchedulerWorker: Found contact_url: #{auto_url}"
      else
        contact_tracking.update!(
          status: '自動送信エラー',  # ← 許可されたstatus値を使用
          sending_completed_at: Time.current
        )
        return
      end
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
      #タイムアウト設定
      require 'timeout'
      stdout, stderr, status = Timeout.timeout(300) do
        Open3.capture3(*command)
      end

      # 送信完了時刻の記録
      contact_tracking.update!(sending_completed_at: Time.current)

      Sidekiq.logger.info "AutoformSchedulerWorker: Python script STDOUT for CT ID #{contact_tracking_id}:\n#{stdout}" unless stdout.blank?
      Sidekiq.logger.error "AutoformSchedulerWorker: Python script STDERR for CT ID #{contact_tracking_id}:\n#{stderr}" unless stderr.blank?

      contact_tracking.reload
      current_status_after_script = contact_tracking.status

      if status.success?
        Sidekiq.logger.info "AutoformSchedulerWorker: Python script completed successfully for CT ID #{contact_tracking_id}. Final DB status: #{current_status_after_script}"
        # 詳細な結果記録を追加
        if current_status_after_script == '送信済'
          contact_tracking.update!(
            sended_at: Time.current,
            response_data: "Success: #{stdout.truncate(500)}"
          )
        elsif current_status_after_script == '処理中'
          contact_tracking.update!(
            status: '自動送信エラー(スクリプト未更新)',
            response_data: "Script completed but status not updated: #{stdout.truncate(500)}"
          )
        end
      else
        # 失敗時処理の詳細記録
        Sidekiq.logger.error "AutoformSchedulerWorker: Python script execution failed for CT ID #{contact_tracking_id}. Exit status: #{status.exitstatus}. DB status before script failure: #{current_status_after_script}"
        
        if current_status_after_script == '処理中'
          contact_tracking.update!(
            status: '自動送信システムエラー(スクリプト失敗)',
            response_data: "Script failed. Exit status: #{status.exitstatus}. STDERR: #{stderr.truncate(500)}"
          )
        end
      end

    rescue Timeout::Error
      Sidekiq.logger.error "AutoformSchedulerWorker: Python script timeout for CT ID #{contact_tracking_id}"
      contact_tracking.update!(
        status: '自動送信エラー(タイムアウト)',
        sending_completed_at: Time.current
      )

    rescue StandardError => e
      # 既存の例外処理に送信完了時刻を追加
      contact_tracking.update!(sending_completed_at: Time.current)
      Sidekiq.logger.error "AutoformSchedulerWorker: Error executing Python script for CT ID #{contact_tracking_id}: #{e.message}"
      Sidekiq.logger.error e.backtrace.join("\n")
      contact_tracking.reload
      if contact_tracking.status == '処理中' || contact_tracking.status == '自動送信予定'
        contact_tracking.update!(
          status: '自動送信システムエラー(ワーカー例外)',
          response_data: "Exception: #{e.message}"
        )
      end
    end
  end

  private
  # URL自動検索機能
  def search_contact_url_automatically(contact_tracking)
    customer = contact_tracking.customer
    
    begin
      # URLからドメイン部分を抽出
      domain = if customer.url.present?
        URI.parse(customer.url).host
      else
        nil
      end

      # ドメインが取得できない場合はスキップ
      return nil unless domain

      # contact_finder.pyを実行
      command = [
        PYTHON_EXECUTABLE,
        Rails.root.join('py_app', 'contact_finder.py').to_s,
        customer.company.to_s,
        domain.to_s
      ]
      
      stdout, stderr, status = Open3.capture3(*command)
      
      if status.success? && stdout.present?
        output = stdout.strip
        
        # MAILTO検出の場合
        if output == 'MAILTO_DETECTED'
          return nil
        end
        
        # 通常のURL（httpで始まる場合）
        if output.present? && output.start_with?('http')
          return output
        end
      end
      
      nil
    rescue => e
      Sidekiq.logger.error "AutoformSchedulerWorker: URL search failed: #{e.message}"
      nil
    end
  end



  # Python出力からURL抽出
  def extract_url_from_output(output)
    # 出力からURLを抽出
    lines = output.split("\n")
    url_line = lines.find { |line| line.include?("http") }
    url_line&.strip
  end

  # 除外ドメインの確認
  def excluded_domain?(url)
    # 除外ドメインの確認
    excluded_domains = ['suumo.jp', 'tabelog.com', 'indeed.com', 'xn--pckua2a7gp15o89zb.com']
    excluded_domains.any? { |domain| url.include?(domain) }
  end
end