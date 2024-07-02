namespace :worker do
    desc "Send warning emails to workers based on their list creation activity"
    task send_warning_emails: :environment do
      # 現在の日付を取得
      today = Date.today
      # 今週の初め（日曜日）を取得
      week_start = today.beginning_of_week(:sunday)
      # 3日前の日付を取得
      three_days_ago = today - 3.days
      # 5日前の日付を取得
      five_days_ago = today - 5.days
  
      Worker.find_each do |worker|
        # 週のlists作成件数をカウント
        weekly_list_count = worker.lists.where(created_at: week_start..today).count
  
        # 最後の作成日
        last_list_date = worker.lists.order(created_at: :desc).first&.created_at
  
        # 条件に基づいて警告メールを送信
        if weekly_list_count < 100
          subject = "Warning: Insufficient List Creation"
          body = "You have created less than 100 lists this week."
          worker.send_warning_email(subject, body)
        end
  
        if last_list_date && last_list_date < five_days_ago
          subject = "Warning: No Activity for 5 Days"
          body = "You have not created any lists in the last 5 days."
          worker.send_warning_email(subject, body)
        end
  
        if last_list_date.nil? && worker.created_at < three_days_ago
          subject = "Warning: No Activity Since Registration"
          body = "You have not created any lists since your registration 3 days ago."
          worker.send_warning_email(subject, body)
        end
      end
    end
  end