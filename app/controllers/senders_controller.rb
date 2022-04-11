class SendersController < ApplicationController
  before_action :authenticate_worker_or_admin!
  before_action :set_sender, only: [:edit, :update]

  def index
    @senders = Sender.all
  end

  def show
    @form = SenderForm.new(
      sender: Sender.find(params[:id]),
      year: params[:year]&.to_i || Time.zone.now.year,
      month: params[:month]&.to_i || Time.zone.now.month,
    )
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
