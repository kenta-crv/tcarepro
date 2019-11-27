class ProgressesController < ApplicationController
  before_action :authenticate_admin!
  def index
		@progresses = Progress.all.order(created_at: 'desc')
	end

	def show
  		@progress = Progress.find(params[:id])
  end

  def new
  	@progress = Progress.new
  end

	def create
    @progress = Progress.new(progress_params)
    if @progress.save
        redirect_to progresses_path
    else
        render 'new'
    end
  end

  def edit
    @progress = Progress.find(params[:id])
  end

 def update
    @progress = Progress.find(params[:id])
     if @progress.update(progress_params)
        redirect_to progresses_path
    else
        render 'edit'
    end
 end

 def destroy
    @progress = Progress.find(params[:id])
    @progress.destroy
    redirect_to progresses_path
 end

private
 def progress_params
  params.require(:progress).permit(
    :statu, #ステータス
    :price, #単価
    :number, #件数
    :history, #過去アポ利用履歴
    :area, #ターゲットエリア
    :target, #対象者
    :next, #次回営業日
    :content, #サービス内容
    :comment #コメント
    )
  end
end
