class ImportsController < ApplicationController
    def create
      # ファイルを受け取る
      file = params[:file]
      raise "File not provided" unless file
  
      # 各インポート処理を非同期ジョブで実行
      BatchImportJob.perform_later(file.path, :import)
      BatchImportJob.perform_later(file.path, :call_import)
      BatchImportJob.perform_later(file.path, :repurpose_import)
      BatchImportJob.perform_later(file.path, :draft_import)
  
      # レスポンスとして進行状況の確認を案内
      render json: { message: "Import job started. Check Sidekiq for progress." }
    end
  end
  