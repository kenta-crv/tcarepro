require 'open3'

class ExtractCompanyInfoWorker
  include Sidekiq::Worker
  # 大量送信の耐久・耐性を確保
  sidekiq_options retry: 1, queue: 'default', backtrace: true

  PYTHON_SCRIPT_PATH = Rails.root.join('extract_company_info', 'app.py').to_s
  PYTHON_EXECUTABLE = 'python3'  # システムのpython3を強制使用

  def perform(id)
    begin
      puts("AutoformSchedulerWorker: perform: start #{id}")

      # すでに他のジョブで本日の残り件数を超えている場合は終了
      today_total = ExtractTracking
                      .where(created_at: Time.current.beginning_of_day..Time.current.end_of_day)
                      .sum(:total_count)
      extract_tracking = ExtractTracking.find(id)
      daily_limit = ENV.fetch('EXTRACT_DAILY_LIMIT', '500').to_i
      today_reamin = daily_limit - (today_total - extract_tracking.total_count)
      if today_reamin == 0 || (extract_tracking.total_count > today_reamin)
        puts("AutoformSchedulerWorker: perform: today limit exceed")
        extract_tracking.update(
          status: "抽出失敗（制限超過）"
        )
        return
      end
      # 実行
      customers = Customer.where(status: ENV.fetch('EXTRACT_AI_STATUS_NAME_EXTRACTING', 'ai_extracting')).where(tel: [nil, '', ' ']).where(industry: extract_tracking.industry).limit(extract_tracking.total_count)
      # ステータス更新
      extract_tracking.update(
        status: "抽出中"
      )
      crowdwork = Crowdwork.find_by(title: extract_tracking.industry)
      success_count = extract_tracking.success_count
      failure_count = extract_tracking.failure_count
      customers.each do |customer|
        begin
          required_businesses =
            if crowdwork.business.present?
              crowdwork.business.split(",")
            else
              []
            end

          required_genre =
            if crowdwork.genre.present?
              crowdwork.genre.split(",")
            else
              []
            end
          command = [PYTHON_EXECUTABLE, PYTHON_SCRIPT_PATH]
          payload = {
            customer_id: customer.id,
            company: customer.company,
            location: customer.address,
            required_businesses: required_businesses,
            required_genre: required_genre
          }

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

            customer.update!(
              company: company,
              tel: tel,
              address: address,
              first_name: first_name,
              url: url,
              contact_url: contact_url,
              business: business,
              genre: genre,
              status: ENV.fetch('EXTRACT_AI_STATUS_NAME_SUCCESS', 'ai_success')
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
            customer.update_columns(
              status: ENV.fetch('EXTRACT_AI_STATUS_NAME_FAILED', 'ai_failed')
            )
            puts("ExtractCompanyInfoWorker: Python script execution failed for customer ID #{customer.id}. Exit status: #{status.exitstatus}")
            puts(stderr)
          end
        rescue => e
          puts "エラー: #{e.class} - #{e.message}"
          failure_count += 1
          extract_tracking.update(
            failure_count: failure_count,
          )
          customer.update_columns(
            status: ENV.fetch('EXTRACT_AI_STATUS_NAME_FAILED', 'ai_failed')
          )
        end
      end
      extract_tracking.update(
        success_count: success_count,
        failure_count: failure_count,
        status: "抽出完了"
      )
    rescue => e
      puts "エラー: #{e.class} - #{e.message}"
    end
  end

  def execute_python_with_timeout(command, stdin_data)
    puts("python script start")
    require 'timeout'
    stdout, stderr, status = Timeout.timeout(300) do
      # 環境変数を渡しつつ、JSONをstdinで投入
      Open3.capture3(
        { "RAILS_ENV" => Rails.env, "PYTHONIOENCODING" => "utf-8" },
        *command,
        stdin_data: stdin_data.encode("UTF-8"),
      )

    end    
    [stdout, stderr, status]
  end

end
