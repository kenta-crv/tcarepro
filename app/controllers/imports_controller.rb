class ImportsController < ApplicationController
    def create
      # ファイルを受け取る
      file = params[:file]
      raise "File not provided" unless file
  
      # ファイルを一時ディレクトリに保存
      temp_file_path = Rails.root.join('tmp', file.original_filename)
      File.open(temp_file_path, 'wb') do |temp_file|
        temp_file.write(file.read)
      end
  
      # 各インポート処理を非同期ジョブで実行
      BatchImportJob.perform_later(temp_file_path.to_s, :import)
      BatchImportJob.perform_later(temp_file_path.to_s, :call_import)
      BatchImportJob.perform_later(temp_file_path.to_s, :repurpose_import)
      BatchImportJob.perform_later(temp_file_path.to_s, :draft_import)
  
      # レスポンスとして進行状況の確認を案内
      render json: { message: "Import job started. Check Sidekiq for progress." }
    end
  end
  