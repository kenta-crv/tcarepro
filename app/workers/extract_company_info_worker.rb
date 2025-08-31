require 'open3'

class ExtractCompanyInfoWorker
  include Sidekiq::Worker
  # 大量送信の耐久・耐性を確保
  sidekiq_options retry: 1, queue: 'default', backtrace: true

  PYTHON_SCRIPT_PATH = Rails.root.join('extract_company_info', 'main.py').to_s
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
      customers = Customer.where(status: "draft").where(tel: [nil, '', ' ']).where(industry: extract_tracking.industry).limit(extract_tracking.total_count)
      crowdwork = Crowdwork.find_by(title: extract_tracking.industry)
      success_count = extract_tracking.success_count
      failure_count = extract_tracking.failure_count
      customers.each do |customer|

        business = crowdwork.business || ""
        genre = customer.genre || ""

        command = [PYTHON_EXECUTABLE, PYTHON_SCRIPT_PATH] + [customer.company, customer.address, business, genre]
        begin
          stdout, stderr, status = execute_python_with_timeout(command)
          if status.success?
            puts("start parse")
            company = tel = address = first_name = url = contact_url = business = genre = "不明"
            stdout.each_line do |raw|
              puts(raw)
              line = raw.to_s.strip.sub(/\A\s*[\-\*\u30fb・]\s*/, "")
              case line
              when /\A会社名[^:：]*[:：]\s*(.+)\z/i
                company = $1.strip
                
              when /\A電話番号[^:：]*[:：]\s*(.+)\z/i
                tel = $1.strip

              when /\A住所[^:：]*[:：]\s*(.+)\z/i
                address = $1.strip

              when /\A代表者[^:：]*[:：]\s*(.+)\z/i
                first_name = $1.strip
              
              when /\AURL[^:：]*[:：]\s*(.+)\z/i
                url = $1.strip
              # 「問い合わせ/お問い合わせ/お問い合わせ先」などの表記ゆれに対応しつつ、コロン直前は任意文字
              when /\A(?:お?\s*問い合わせ|問い合わせ)\s*(?:先)?\s*URL[^:：]*[:：]\s*(\S+)\z/i
                contact_url = $1.strip

              when /\A業種[^:：]*[:：]\s*(.+)\z/i
                business = $1.strip

              when /\A事業内容[^:：]*[:：]\s*(.+)\z/i
                if $1.strip == '不明'
                  genre = ''
                else
                  genre = $1.strip
                end
              end
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
            puts("ExtractCompanyInfoWorker: Python script execution failed for customer ID #{customer.id}. Exit status: #{status.exitstatus}")
            puts(stderr)
          end
        rescue => e
          puts "エラー: #{e.class} - #{e.message}"
          failure_count += 1
          extract_tracking.update(
            failure_count: failure_count,
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

  def execute_python_with_timeout(command)
    puts("python script start")
    require 'timeout'
    stdout, stderr, status = Timeout.timeout(300) do
      Open3.capture3(*command)
    end    
    [stdout, stderr, status]
  end

end
