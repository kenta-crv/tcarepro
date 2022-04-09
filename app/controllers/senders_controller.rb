class SendersController < ApplicationController
  before_action :authenticate_worker_or_admin!

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

  private

  def authenticate_worker_or_admin!
    unless worker_signed_in? || admin_signed_in?
       redirect_to new_worker_session_path, alert: 'error'
    end
  end
end
