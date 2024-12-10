class BatchImportJob < ApplicationJob
    queue_as :default
  
    def perform(file_path, import_type)
      # CSVファイルの行数をカウント
      total_rows = CSV.read(file_path, headers: true).size
      rows_processed = 0
  
      # 各行を処理しつつ、進捗状況をRedisに記録
      CSV.foreach(file_path, headers: true) do |row|
        case import_type
        when :import
          Customer.import_row(row)  # 各行を処理するメソッド
        when :call_import
          Customer.call_import_row(row)
        when :repurpose_import
          Customer.repurpose_import_row(row)
        when :draft_import
          Customer.draft_import_row(row)
        else
          raise "Unknown import type: #{import_type}"
        end
  
        # 処理済みの行数を更新
        rows_processed += 1
        progress = (rows_processed.to_f / total_rows * 100).round(2)
        Redis.current.set("progress_#{import_type}", progress)
      end
    end
  end
  