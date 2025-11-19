require "json"

class ExtractCompanyInfoWorker
  include Sidekiq::Worker
  # 大量送信の耐久・耐性を確保
  sidekiq_options retry: 1, queue: 'default', backtrace: true

  PYTHON_SCRIPT_PATH = Rails.root.join('extract_company_info', 'app.py').to_s
  # 仮想環境のPythonを使用
  PYTHON_VENV_PATH = Rails.root.join('extract_company_info', 'venv', 'bin', 'python').to_s
  PYTHON_EXECUTABLE = if File.exist?(PYTHON_VENV_PATH)
                        PYTHON_VENV_PATH
                      else
                        'python3'
                      end

  def perform(id)
    begin
      Sidekiq.logger.info("ExtractCompanyInfoWorker: perform: start #{id}")

      # すでに他のジョブで本日の残り件数を超えている場合は終了
      extract_tracking = ExtractTracking.find(id)
      daily_limit = ENV.fetch('EXTRACT_DAILY_LIMIT', '500').to_i
      
      # 今日の合計件数（現在のextract_trackingを除く）
      today_total = ExtractTracking
                      .where(created_at: Time.current.beginning_of_day..Time.current.end_of_day)
                      .where.not(id: extract_tracking.id)
                      .sum(:total_count)
      
      # 残り件数を計算（マイナスにならないようにする）
      today_reamin = [daily_limit - today_total, 0].max
      
      if today_reamin == 0 || extract_tracking.total_count > today_reamin
        Sidekiq.logger.warn("ExtractCompanyInfoWorker: today limit exceed (remaining: #{today_reamin}, requested: #{extract_tracking.total_count})")
        extract_tracking.update(
          status: "抽出失敗（制限超過）"
        )
        return
      end
      # 実行（残り件数を超えないように制限）
      limit_count = [extract_tracking.total_count, today_reamin].min
      customers = Customer.where(status: "draft").where(tel: [nil, '', ' ']).where(industry: extract_tracking.industry).limit(limit_count)
      crowdwork = Crowdwork.find_by(title: extract_tracking.industry)
      success_count = extract_tracking.success_count
      failure_count = extract_tracking.failure_count
      quota_exceeded = false
      customer_count = customers.count
      customers.each_with_index do |customer, index|
        required_businesses =
          if crowdwork&.business.present?
            crowdwork.business.split(",")
          else
            []
          end

        required_genre =
          if crowdwork&.genre.present?
            crowdwork.genre.split(",")
          else
            []
          end
        command = [PYTHON_EXECUTABLE, PYTHON_SCRIPT_PATH]
        payload = {
          customer_id: customer.id.to_s,  # 文字列に変換
          company: customer.company.to_s,
          location: customer.address.to_s,
          required_businesses: required_businesses,
          required_genre: required_genre
        }
        begin
          stdout, stderr, status = execute_python_with_timeout(command, payload.to_json)
          if status.success?
            # JSONで受け取り、顧客情報を更新
            data = JSON.parse(stdout.strip) rescue nil
            unless data.is_a?(Hash)
              raise "invalid json stdout"
            end

            company = data['data']['company'].to_s
            tel = data['data']['tel'].to_s
            address = data['data']['address'].to_s
            first_name = data['data']['first_name'].to_s
            url = data['data']['url'].to_s
            contact_url = data['data']['contact_url'].to_s
            business = data['data']['business'].to_s
            genre = data['data']['genre'].to_s

            # businessとgenreがバリデーション要件を満たしているかチェック
            business_valid = if crowdwork&.business.present?
                              required_businesses_array = crowdwork.business.split(',').map(&:strip)
                              business.present? && required_businesses_array.any? { |req| business.include?(req) }
                            else
                              business.present?
                            end

            genre_valid = if crowdwork&.genre.present?
                           required_genre_array = crowdwork.genre.split(',').map(&:strip)
                           genre.present? && required_genre_array.any? { |req| genre.include?(req) }
                         else
                           genre.present?
                         end

            # バリデーション要件を満たしていない場合は失敗として扱う
            unless business_valid && genre_valid
              Sidekiq.logger.warn("ExtractCompanyInfoWorker: バリデーション要件を満たしていないため失敗: customer_id=#{customer.id}, business=#{business.inspect}, genre=#{genre.inspect}")
              failure_count += 1
              extract_tracking.update(
                failure_count: failure_count,
              )
              next
            end

            customer.update!(
              company: company,
              tel: tel,
              address: address,
              first_name: first_name,
              url: url,
              contact_url: contact_url,
              business: business,
              genre: genre
            )
            success_count += 1
            extract_tracking.update(
              success_count: success_count,
            )
          else
            failure_count += 1
            extract_tracking.update(
              failure_count: failure_count,
            )
            Sidekiq.logger.error("ExtractCompanyInfoWorker: Python script execution failed for customer ID #{customer.id}. Exit status: #{status.exitstatus}")
            Sidekiq.logger.error("ExtractCompanyInfoWorker: stderr: #{stderr}")

            # Python側からのエラーコードを解析（例: QUOTA_EXCEEDED）
            begin
              response_json = JSON.parse(stdout.strip)
              error_code = response_json.dig("error", "code")
            rescue JSON::ParserError
              error_code = nil
            end

            if error_code == "QUOTA_EXCEEDED"
              Sidekiq.logger.warn("ExtractCompanyInfoWorker: Gemini APIクォータ超過が検出されたため処理を一時停止します")
              quota_exceeded = true
              extract_tracking.update(status: "抽出停止（API制限）")
              break
            elsif error_code == "RATE_LIMIT_ERROR"
              # 一時的なレート制限の場合は、短い待機後に続行を試みる
              Sidekiq.logger.warn("ExtractCompanyInfoWorker: Gemini API一時的なレート制限エラー（クォータ超過ではない可能性）")
              Sidekiq.logger.warn("ExtractCompanyInfoWorker: 30秒待機して続行を試みます...")
              sleep(30)
              # 続行を試みる（breakしない）
            end
          end
        rescue => e
          Sidekiq.logger.error("ExtractCompanyInfoWorker: Error processing customer #{customer.id}: #{e.class} - #{e.message}")
          Sidekiq.logger.error(e.backtrace.join("\n")) if e.backtrace
          failure_count += 1
          extract_tracking.update(
            failure_count: failure_count,
          )
        end
        
        # API呼び出し間隔を空ける（最後の顧客処理後とbreakで終了する場合はスリープしない）
        # 無料プラン（RPM=15）を考慮し、5秒待機（1分間に12回以下に制限）
        # Python側でもAPI呼び出し間隔を空けているため、Worker側は5秒で十分
        unless quota_exceeded || index == customer_count - 1
          Sidekiq.logger.info("ExtractCompanyInfoWorker: API呼び出し間隔のため5秒待機中... (#{index + 1}/#{customer_count})")
          sleep(5)  # 10秒 → 5秒に短縮（パフォーマンス改善）
        end
      end
      # QUOTA_EXCEEDEDで停止した場合は、ステータスを「抽出完了」に更新しない
      unless quota_exceeded
        extract_tracking.update(
          success_count: success_count,
          failure_count: failure_count,
          status: "抽出完了"
        )
      end
    rescue => e
      Sidekiq.logger.error("ExtractCompanyInfoWorker: Fatal error: #{e.class} - #{e.message}")
      Sidekiq.logger.error(e.backtrace.join("\n")) if e.backtrace
    end
  end

  def execute_python_with_timeout(command, stdin_data, timeout: 300)
    stdout_str = +""
    stderr_str = +""
    status = nil
    Sidekiq.logger.debug("ExtractCompanyInfoWorker: Python script start")
    require 'open3'
    
    Open3.popen3({ "RAILS_ENV" => Rails.env, "PYTHONIOENCODING" => "utf-8" }, *command) do |stdin, stdout, stderr, wait_thr|
      begin
        stdin.write(stdin_data.encode("UTF-8"))
      rescue Errno::EPIPE
        # 子プロセスが先に終了していても無視
      ensure
        stdin.close
      end

      out_reader = Thread.new do
        begin
          stdout.each_line { |line| stdout_str << line }
        rescue IOError, Errno::EIO
          # パイプ競合は無視
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
        Sidekiq.logger.warn("ExtractCompanyInfoWorker: Python script timeout after #{timeout} seconds")
      end

      out_reader.join
      err_reader.join
      status = wait_thr.value
    end

    [stdout_str, stderr_str, status]
  end

end
