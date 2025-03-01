class BatchImportJob < ApplicationJob
    queue_as :default
  
    def perform(file_path, import_type)
      # CSVファイルの行数をカウント
      file = File.open(file_path)
      case import_type
      when "import"
        Customer.import(file) # 各行を処理するメソッド
      when "call_import"
        Customer.call_import(file)
      when "repurpose_import"
        Customer.repurpose_import(file)
      when "draft_import"
        Customer.draft_import(file)
      else
        raise "Unknown import type: #{import_type}"
      end
  
      # 処理後にファイルを削除
      File.delete(file_path) if File.exist?(file_path)
    end
  end
  