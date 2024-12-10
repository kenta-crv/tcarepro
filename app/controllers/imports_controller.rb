class ImportsController < ApplicationController
    def create
      file = params[:file]
      if file.nil?
        render json: { error: "File not provided" }, status: :bad_request
        return
      end
  
      # ファイルを一時ディレクトリに保存
      temp_file_path = Rails.root.join('tmp', file.original_filename)
      File.open(temp_file_path, 'wb') do |temp_file|
        temp_file.write(file.read)
      end
  
      # 非同期ジョブで各インポート処理をキューに登録
      begin
        BatchImportJob.perform_later(temp_file_path.to_s, :import)
        BatchImportJob.perform_later(temp_file_path.to_s, :call_import)
        BatchImportJob.perform_later(temp_file_path.to_s, :repurpose_import)
        BatchImportJob.perform_later(temp_file_path.to_s, :draft_import)
  
        render json: { message: "Import job started. Check Sidekiq for progress." }
      rescue => e
        # ジョブ登録時のエラーをキャッチ
        render json: { error: "Failed to enqueue jobs: #{e.message}" }, status: :internal_server_error
      end
    end
  end
  