class SendersHistoryController < ApplicationController
  layout "send"
  before_action :authenticate_worker_or_admin_or_sender!
  before_action :set_sender

  def index
    @contact_trackings = contact_trackings
  end

  def sended
    @contact_trackings = contact_trackings.where(status: '送信済')
  end

  def callbacked
    @contact_trackings = contact_trackings.where(status: '送信済').where.not(callbacked_at: nil)
  end

  private

  def set_sender
    if sender_signed_in?
      @sender = current_sender
    else
      @sender = Sender.find(params[:sender_id])
    end
  end

  def contact_trackings
    current_month = Date.new(params[:year].to_i, params[:month].to_i, 1)

    @sender
      .contact_trackings
      .where(created_at: current_month...(current_month + 1.month))
      .order(created_at: :desc)
  end

  def authenticate_worker_or_admin_or_sender!
    unless worker_signed_in? || admin_signed_in? || sender_signed_in?
       redirect_to new_worker_session_path, alert: 'error'
    end
  end
end
