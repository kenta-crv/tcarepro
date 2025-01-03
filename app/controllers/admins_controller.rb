class AdminsController < ApplicationController
  def show
    @admin = Admin.find(params[:id])
    @senders = Sender.all
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

  def assign_senders
    params[:sender_ids].each do |worker_id, sender_id|
      worker = Worker.find(worker_id)
      sender = Sender.find_by(id: sender_id)

      if sender
        # 既存の割り当てを削除して新規割り当てを作成
        worker.sender_assignments.destroy_all
        worker.senders << sender
      end
    end
    redirect_to admin_path, notice: '送信先を割り当てました。'
  end

  def remove_sender
    sender_assignment = SenderAssignment.find_by(worker_id: params[:worker_id], sender_id: params[:sender_id])
    if sender_assignment
      sender_assignment.destroy
      flash[:notice] = '送信先を解除しました。'
    else
      flash[:alert] = '送信先の解除に失敗しました。'
    end
    redirect_to admin_path
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
