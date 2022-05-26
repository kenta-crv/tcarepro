class SendersHistoryController < ApplicationController
  before_action :authenticate_worker_or_admin_or_sender_or_user!, only: [:callbacked]
  before_action :authenticate_worker_or_admin_or_sender!, only: [:index,:sended,:download_sended]
  before_action :authenticate_user!, only: [:users_callbacked]
  before_action :set_sender

  def index
    @contact_trackings = contact_trackings
  end

  def sended
    @contact_trackings = contact_trackings.where(status: '送信済')
  end
  
  
  def download_sended
    Rails.logger.info("contact_trackings :" + @sender.contact_trackings.to_yaml)
    @contact_trackings = contact_trackings.where(status: '送信済')
    Rails.logger.info("@contact_trackings :" + @contact_trackings.to_yaml)
    call_attributes = ["customer_id" ,"status", "inquiry_id","created_at","sended_at"]
      generate_sended =
        CSV.generate(headers:true) do |csv|
          csv << call_attributes
          @contact_trackings.all.each do |task|
            Rails.logger.info("task :" + task.attributes.inspect)
            csv << call_attributes.map{|attr| task.send(attr)}
          end
        end
      respond_to do |format|
        format.html
        format.csv{ send_data generate_sended, filename: "sended-#{Time.zone.now.strftime('%Y%m%d%S')}.csv" }
      end
  end
  
  def download_callbacked
    @contact_trackings = contact_trackings.where.not(callbacked_at: nil)
    Rails.logger.info("@contact_trackings :" + @contact_trackings.to_yaml)
    call_attributes = ["customer_id" ,"status", "inquiry_id","created_at","sended_at"]
      generate_callbacked =
        CSV.generate(headers:true) do |csv|
          csv << call_attributes
          @contact_trackings.all.each do |task|
            Rails.logger.info("task :" + task.attributes.inspect)
            csv << call_attributes.map{|attr| task.send(attr)}
          end
        end
      respond_to do |format|
        format.html
        format.csv{ send_data generate_callbacked, filename: "callbacked-#{Time.zone.now.strftime('%Y%m%d%S')}.csv" }
      end
  end

  def callbacked
     Rails.logger.info("contact_trackings before :" + contact_trackings.to_yaml)
    @contact_trackings = contact_trackings.where.not(callbacked_at: nil)
    Rails.logger.info("contact_trackings :" + @contact_trackings.to_yaml)
  end

  def users_callbacked
     Rails.logger.info("contact_trackings before :" + contact_trackings.to_yaml)
    @contact_trackings = contact_trackings.where.not(callbacked_at: nil)
    Rails.logger.info("contact_trackings :" + @contact_trackings.to_yaml)
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
  def authenticate_user!
    unless user_signed_in? 
       redirect_to new_user_session_path, alert: 'error'
    end
  end
  def authenticate_worker_or_admin_or_sender_or_user!
    unless worker_signed_in? || admin_signed_in? || sender_signed_in?|| user_signed_in?
       redirect_to new_worker_session_path, alert: 'error'
    end
  end
end
