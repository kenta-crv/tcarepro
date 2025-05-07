class AdminsController < ApplicationController
  def show
    @admin =  Admin.find(params[:id])
    @workers = Worker.all

    # 各ワーカーに関連する最新のCrowdworkを取得する
    @assigned_crowdworks = @workers.index_by(&:id).transform_values do |worker|
      worker.crowdworks.order(created_at: :desc).first  # 最新のCrowdworkを取得
    end
  end

  def assign_workers
    @admin = Admin.find(params[:id])
    
    # crowdwork_idsを取得
    crowdwork_ids = params[:crowdwork_ids] || {}
    
    crowdwork_ids.each do |worker_id, crowdwork_id|
      next if crowdwork_id.blank?  # 空の場合はスキップ
  
      # crowdworkを取得
      crowdwork = Crowdwork.find(crowdwork_id)
  
      # workerを取得
      worker = Worker.find(worker_id)
  
      # 割り当て
      unless crowdwork.workers.exists?(worker.id)
        crowdwork.workers << worker
      end
    end
  
    redirect_to admin_path(@admin), notice: 'ワーカーが正常に割り当てられました。'
  end
  
  def remove_worker
    @admin = Admin.find(params[:id])
    crowdwork = Crowdwork.find(params[:crowdwork_id])
    worker = Worker.find(params[:worker_id])
  
    # 削除処理
    crowdwork.workers.delete(worker)
  
    redirect_to admin_path(@admin), notice: 'ワーカーが解除されました。'
  end
  
  private

  def assign_workers_params
    params.permit(:crowdwork_id, worker_ids: [])
  end
end
