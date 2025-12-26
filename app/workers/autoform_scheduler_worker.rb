require 'open3'

class AutoformSchedulerWorker
  include Sidekiq::Worker
  # 大量送信の耐久・耐性を確保
  sidekiq_options retry: 3, queue: 'default', backtrace: true

  PYTHON_SCRIPT_PATH = Rails.root.join('autoform', 'bootio.py').to_s
  # Try virtual environment first, then system Python
  VENV_PYTHON = Rails.root.join('autoform', '.venv', 'Scripts', 'python.exe').to_s
  PYTHON_EXECUTABLE = if File.exist?(VENV_PYTHON)
    VENV_PYTHON
  elsif RUBY_PLATFORM =~ /mswin|mingw|cygwin/
    'python'  # Windows uses 'python', not 'python3'
  else
    'python3'  # Unix/Linux uses 'python3'
  end

  def perform(contact_tracking_id)
    contact_tracking = ContactTracking.find_by(id: contact_tracking_id)
    unless contact_tracking
      Sidekiq.logger.error "AutoformSchedulerWorker: ContactTracking with ID #{contact_tracking_id} not found."
      return
    end

    contact_tracking = ContactTracking.find_by(id: contact_tracking_id)
    unless contact_tracking
      Sidekiq.logger.error "AutoformSchedulerWorker: ContactTracking with ID #{contact_tracking_id} not found."
      return
    end

    ContactTracking.transaction do
      begin
        # Check if this is a scheduled submission (自動送信予定)
        # If so, let the Python bootio.py service handle it (it polls the database)
        # The Sidekiq worker should not execute Python for scheduled submissions
        if contact_tracking.status == '自動送信予定'
          Sidekiq.logger.info "AutoformSchedulerWorker: ContactTracking ID #{contact_tracking_id} is scheduled. Python bootio.py service will handle execution. Skipping Python call."
          # Don't change status - let Python service handle it
          return
        end

        # 送信開始状態の記録
        contact_tracking.update!(
          status: '送信中',
          sending_started_at: Time.current
        )

        # URL自動検索機能
        # app/workers/autoform_scheduler_worker.rb の修正
        if contact_tracking.contact_url.blank?
          auto_url = search_contact_url_automatically(contact_tracking)
          
          if auto_url.present?
            # 見つけたURLをContactTrackingに保存
            contact_tracking.update!(contact_url: auto_url)
            Rails.logger.info "AutoformSchedulerWorker: Found and saved contact_url: #{auto_url}"
          else
            Rails.logger.warn "AutoformSchedulerWorker: Could not find contact_url for CT ID #{contact_tracking_id}"
            contact_tracking.update!(
              status: '自動送信エラー',
              sending_completed_at: Time.current,
              response_data: 'URL自動検索に失敗しました'
            )
            return
          end
        end

        # Always use the most recently updated inquiry
        inquiry = Inquiry.order(updated_at: :desc).first
        unless inquiry
          error_message = "No Inquiry records found."
          Sidekiq.logger.error "AutoformSchedulerWorker: #{error_message}"
          contact_tracking.update!(
            status: '自動送信エラー(データ無)',
            sending_completed_at: Time.current,
            response_data: error_message
          )
          return
        end

        # Python引数の構築
        args = build_python_args(contact_tracking, inquiry)

        # Python実行可能性チェック
        unless python_executable_available?
          error_message = "Python executable '#{PYTHON_EXECUTABLE}' not found."
          Sidekiq.logger.fatal "AutoformSchedulerWorker: #{error_message}"
          contact_tracking.update!(
            status: '自動送信システムエラー(Py無)',
            sending_completed_at: Time.current,
            response_data: error_message
          )
          return
        end

        # Python送信処理実行
        command = [PYTHON_EXECUTABLE, PYTHON_SCRIPT_PATH] + args.map(&:to_s)
        Sidekiq.logger.info "AutoformSchedulerWorker: Executing command for CT ID #{contact_tracking_id}: #{command.join(' ')}"
        
        # 処理中ステータスに変更
        contact_tracking.update!(status: '処理中')

        # Python実行（タイムアウト付き）
        stdout, stderr, status = execute_python_with_timeout(command, contact_tracking_id)

        # 送信完了時刻の記録
        contact_tracking.update!(sending_completed_at: Time.current)

        # 送信結果の検証と適切なステータス更新
        process_python_result(contact_tracking, stdout, stderr, status)

      rescue Timeout::Error => e
        Sidekiq.logger.error "AutoformSchedulerWorker: Python script timeout for CT ID #{contact_tracking_id}"
        contact_tracking.update!(
          status: '自動送信エラー(タイムアウト)',
          sending_completed_at: Time.current,
          response_data: "Timeout after 300 seconds"
        )
        raise e unless should_not_retry?(e)

      rescue StandardError => e
        Sidekiq.logger.error "AutoformSchedulerWorker: Error executing Python script for CT ID #{contact_tracking_id}: #{e.message}"
        Sidekiq.logger.error e.backtrace.join("\n")
        
        contact_tracking.update!(
          status: '自動送信システムエラー(ワーカー例外)',
          sending_completed_at: Time.current,
          response_data: "Exception: #{e.message}"
        )
        raise e unless should_not_retry?(e)
      end
    end
  end

  private

  def build_python_args(contact_tracking, inquiry)
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

    args
  end

  def python_executable_available?
    return false unless PYTHON_EXECUTABLE
    
    # Check if it's an absolute path that exists
    return true if File.exist?(PYTHON_EXECUTABLE)
    
    # Check if it's available in PATH (works on both Windows and Unix)
    if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
      # Windows: use 'where' command
      system("where #{PYTHON_EXECUTABLE} >nul 2>&1")
    else
      # Unix/Linux: use 'which' command
      system("which #{PYTHON_EXECUTABLE} > /dev/null 2>&1")
    end
  end

  def execute_python_with_timeout(command, contact_tracking_id, timeout: 300)
    stdout_str = +""
    stderr_str = +""
    status = nil
    require 'open3'
    
    Open3.popen3({ "RAILS_ENV" => Rails.env, "PYTHONIOENCODING" => "utf-8" }, *command) do |stdin, stdout, stderr, wait_thr|
      stdin.close

      out_reader = Thread.new do
        begin
          stdout.each_line { |line| stdout_str << line }
        rescue IOError, Errno::EIO
        end
      end

      err_reader = Thread.new do
        begin
          stderr.each_line { |line| stderr_str << line }
        rescue IOError, Errno::EIO
        end
      end

      unless wait_thr.join(timeout)
        pid = wait_thr.pid
        Process.kill("TERM", pid) rescue nil
        unless wait_thr.join(5)
          Process.kill("KILL", pid) rescue nil
          wait_thr.join
        end
        Sidekiq.logger.error "AutoformSchedulerWorker: Python script timeout for CT ID #{contact_tracking_id}"
      end

      out_reader.join
      err_reader.join
      status = wait_thr.value
    end

    # ログ出力
    Sidekiq.logger.info "AutoformSchedulerWorker: Python script STDOUT for CT ID #{contact_tracking_id}:\n#{stdout_str}" unless stdout_str.blank?
    Sidekiq.logger.error "AutoformSchedulerWorker: Python script STDERR for CT ID #{contact_tracking_id}:\n#{stderr_str}" unless stderr_str.blank?

    [stdout_str, stderr_str, status]
  end

  def process_python_result(contact_tracking, stdout, stderr, status)
    contact_tracking.reload
    current_status_after_script = contact_tracking.status

    if status.success?
      Sidekiq.logger.info "AutoformSchedulerWorker: Python script completed successfully for CT ID #{contact_tracking.id}. Final DB status: #{current_status_after_script}"
      
      # 送信成功の判定
      if current_status_after_script == '送信済'
        contact_tracking.update!(
          sended_at: Time.current,
          response_data: "Success: #{stdout.truncate(500)}"
        )
      elsif current_status_after_script == '処理中'
        # Pythonスクリプトは成功したが、DBステータスが更新されていない場合
        if sending_appears_successful?(stdout)
          contact_tracking.update!(
            status: '送信済',
            sended_at: Time.current,
            response_data: "Auto-detected success: #{stdout.truncate(500)}"
          )
        else
          contact_tracking.update!(
            status: '自動送信エラー(スクリプト未更新)',
            response_data: "Script completed but status not updated: #{stdout.truncate(500)}"
          )
        end
      end
    else
      # Python実行失敗時の処理
      Sidekiq.logger.error "AutoformSchedulerWorker: Python script execution failed for CT ID #{contact_tracking.id}. Exit status: #{status.exitstatus}"
      
      if current_status_after_script == '処理中'
        contact_tracking.update!(
          status: '自動送信システムエラー(スクリプト失敗)',
          response_data: "Script failed. Exit status: #{status.exitstatus}. STDERR: #{stderr.truncate(500)}"
        )
      end
    end
  end

  def sending_appears_successful?(stdout)
    return false if stdout.blank?
    
    # 成功パターンを検出
    success_patterns = [
      'success', 'sent', 'submitted', 'completed', 'ok',
      '送信完了', '送信成功', '正常終了'
    ]
    
    stdout_lower = stdout.downcase
    success_patterns.any? { |pattern| stdout_lower.include?(pattern) }
  end

  def should_not_retry?(exception)
    # バリデーションエラーや永続的なエラーの場合はリトライしない
    exception.is_a?(ActiveRecord::RecordInvalid) ||
    exception.is_a?(ActiveRecord::RecordNotFound) ||
    exception.message.include?('バリデーション') ||
    exception.message.include?('not found')
  end

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

  # 自動修正機能
  def self.fix_stuck_records
    ContactTracking.auto_fix_stuck_records
  end

  # 健全性チェック
  def self.health_check
    stuck_count = ContactTracking.where(status: '処理中').count
    abnormal_count = ContactTracking.abnormal_processing_records.count
    
    {
      stuck_processing_records: stuck_count,
      abnormal_processing_records: abnormal_count,
      healthy: stuck_count == 0 && abnormal_count == 0
    }
  end
end