class AdminsController < ApplicationController
  def show
    @admin = Admin.find(params[:id])
    @senders = Sender.all
    @workers = Worker.all

    # 各ワーカーに関連するCrowdworkを取得する
    @assigned_crowdworks = @workers.index_by(&:id).transform_values { |worker| worker.crowdworks.first }
  end
  def assign_workers
    @admin = Admin.find(params[:id])
    crowdwork = Crowdwork.find(params[:crowdwork_id])
    worker_ids = params[:worker_ids] || []

    # 既存の割り当てを保持しつつ、新しい割り当てを追加
    current_worker_ids = crowdwork.worker_ids
    new_worker_ids = current_worker_ids | worker_ids.map(&:to_i)  # 既存と新しいワーカーのIDを統合

    # 更新された割り当てを保存
    crowdwork.worker_ids = new_worker_ids

    redirect_to admin_path(@admin), notice: 'ワーカーが割り当てられました。'
  end
end
