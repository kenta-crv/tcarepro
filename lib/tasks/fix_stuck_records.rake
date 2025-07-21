namespace :tcarepro do
  desc "処理中で停止しているレコードを修正"
  task fix_stuck_records: :environment do
    puts "=" * 50
    puts "処理中レコードの修正を開始..."
    puts "=" * 50

    # 現在の処理中レコードを確認
    all_stuck = ContactTracking.where(status: '処理中')
    puts "全処理中レコード: #{all_stuck.count}件"

    # 1. 送信完了済みだが状態が更新されていないレコード（処理時間が1秒以上）
    completed_stuck = ContactTracking.completed_but_not_updated_records

    puts "\n【1. 完了済み未更新レコード】"
    puts "対象レコード: #{completed_stuck.count}件"

    success_count = 0
    completed_stuck.find_each do |record|
      begin
        record.update!(
          status: '送信済',
          sended_at: record.sending_completed_at,
          updated_at: Time.current
        )
        puts "✓ 修正完了: ID #{record.id} (送信済に変更)"
        success_count += 1
      rescue => e
        puts "✗ 修正失敗: ID #{record.id} - #{e.message}"
      end
    end
    puts "修正完了: #{success_count}件"

    # 2. 異常に短い処理時間のレコード（1秒未満）
    abnormal_records = ContactTracking.abnormal_processing_records

    puts "\n【2. 異常処理時間レコード】"
    puts "対象レコード: #{abnormal_records.count}件"

    if abnormal_records.any?
      abnormal_records.find_each do |record|
        processing_time = record.processing_duration
        puts "ID #{record.id}: 処理時間 #{processing_time.round(3)}秒"
      end

      updated_count = abnormal_records.update_all(
        status: '自動送信エラー',
        updated_at: Time.current
      )
      puts "自動送信エラーに変更: #{updated_count}件"
    end

    # 3. 送信未完了レコード（sending_completed_at が nil）
    incomplete_records = ContactTracking.where(status: '処理中')
                                       .where(sending_completed_at: nil)

    puts "\n【3. 送信未完了レコード】"
    puts "対象レコード: #{incomplete_records.count}件"

    if incomplete_records.any?
      # 24時間以上前のレコードはエラー状態に
      old_incomplete = incomplete_records.where('created_at < ?', 24.hours.ago)
      puts "24時間以上前のレコード: #{old_incomplete.count}件"

      if old_incomplete.any?
        old_updated = old_incomplete.update_all(
          status: '自動送信エラー',
          sending_completed_at: Time.current,
          updated_at: Time.current
        )
        puts "古い未完了レコードをエラー状態に変更: #{old_updated}件"
      end

      # 最近のレコードは状況を表示
      recent_incomplete = incomplete_records.where('created_at >= ?', 24.hours.ago)
      puts "最近の未完了レコード: #{recent_incomplete.count}件（手動確認推奨）"
    end

    # 4. 最終結果の確認
    puts "\n【修正結果確認】"
    remaining_stuck = ContactTracking.where(status: '処理中')
    puts "残り処理中レコード: #{remaining_stuck.count}件"

    if remaining_stuck.any?
      puts "\n残りの処理中レコード詳細:"
      remaining_stuck.limit(10).each do |record|
        puts "ID #{record.id}: 作成 #{record.created_at}, 開始 #{record.sending_started_at}, 完了 #{record.sending_completed_at}"
      end
    end

    puts "\n=" * 50
    puts "修正完了"
    puts "=" * 50
  end

  desc "sender毎の検索テスト"
  task test_sender_isolation: :environment do
    puts "=" * 50
    puts "sender分離テスト開始..."
    puts "=" * 50

    # 各senderのレコード数を確認
    sender_counts = ContactTracking.group(:sender_id).count
    puts "sender毎のレコード数:"
    sender_counts.each do |sender_id, count|
      puts "  Sender #{sender_id}: #{count}件"
    end

    # 特定のsenderでの検索テスト
    if sender_counts.any?
      test_sender_id = sender_counts.keys.first
      puts "\n検索テスト (Sender #{test_sender_id}):"
      
      # 全件検索
      all_records = ContactTracking.for_sender(test_sender_id)
      puts "  全件: #{all_records.count}件"
      
      # ステータス別検索
      status_counts = all_records.group(:status).count
      puts "  ステータス別:"
      status_counts.each do |status, count|
        puts "    #{status}: #{count}件"
      end
    end

    puts "\n=" * 50
    puts "テスト完了"
    puts "=" * 50
  end

  desc "システム健全性チェック"
  task health_check: :environment do
    puts "=" * 50
    puts "システム健全性チェック開始..."
    puts "=" * 50

    health_report = AutoformSchedulerWorker.health_check
    
    puts "健全性レポート:"
    puts "  処理中レコード: #{health_report[:stuck_processing_records]}件"
    puts "  異常処理レコード: #{health_report[:abnormal_processing_records]}件"
    puts "  システム状態: #{health_report[:healthy] ? '正常' : '異常'}"

    unless health_report[:healthy]
      puts "\n問題が検出されました。fix_stuck_recordsタスクを実行してください。"
      puts "実行コマンド: bundle exec rake tcarepro:fix_stuck_records"
    end

    puts "\n=" * 50
    puts "チェック完了"
    puts "=" * 50
  end

  desc "自動修正実行"
  task auto_fix: :environment do
    puts "自動修正を実行中..."
    
    begin
      ContactTracking.auto_fix_stuck_records
      puts "自動修正完了"
    rescue => e
      puts "自動修正中にエラーが発生しました: #{e.message}"
    end
  end
end