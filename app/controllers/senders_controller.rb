class SendersController < ApplicationController
  before_action :authenticate_worker_or_admin!, except: [:show]
  before_action :set_sender, only: [:edit, :update]

  def index
    @senders = Sender.all
  end

  def show
    @call
    @form = SenderForm.new(
      sender: Sender.find(params[:id]),
      year: params[:year]&.to_i || Time.zone.now.year,
      month: params[:month]&.to_i || Time.zone.now.month,
    )
    @data = AutoformResult.where(sender_id:params[:id])
  end

  def import
    Rails.logger.info("params id:"+params[:id].to_s )
    if worker_signed_in?
      sender = Sender.find(params[:id])
      cnt = NgCustomer.import(params[:update_file],sender,nil)
      redirect_to '/senders/'+sender.id.to_s, notice:"#{cnt}件登録されました。"
    else
      sender = Admin.find(params[:id])
      cnt = NgCustomer.import(params[:update_file],nil,sender)
      redirect_to '/admins/'+sender.id.to_s, notice:"#{cnt}件登録されました。"
    end
  end

  def edit
  end


  def update
    if @sender.update(sender_params)
      redirect_to senders_path
    else
      render 'edit'
    end
  end

  private

  def sender_params
    params.require(:sender).permit(:user_name, :rate_limit, :email)
  end

  def set_sender
    @sender = Sender.find(params[:id])
  end

  def authenticate_worker_or_admin!
    unless worker_signed_in? || admin_signed_in?
       redirect_to new_worker_session_path, alert: 'error'
    end
  end
end
