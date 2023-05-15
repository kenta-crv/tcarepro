class SendlistController < ApplicationController

    before_action :authenticate_user_or_admin
  
    def index
      @last_call_params = {}
      if params[:last_call] && !params[:last_call].values.all?(&:blank?)
        @last_call_params = params[:last_call]
        last_call = Call.joins_last_call.select(:customer_id)
        last_call = last_call.where(statu: @last_call_params[:statu]) if !@last_call_params[:statu].blank?
        last_call = last_call.where("calls.time >= ?", @last_call_params[:time_from]) if !@last_call_params[:time_from].blank?
        last_call = last_call.where("calls.time <= ?", @last_call_params[:time_to]) if !@last_call_params[:time_to].blank?
        last_call = last_call.where("calls.created_at >= ?", @last_call_params[:created_at_from]) if !@last_call_params[:created_at_from].blank?
        last_call = last_call.where("calls.created_at <= ?", @last_call_params[:created_at_to]) if !@last_call_params[:created_at_to].blank?
      end
      @q = Customer.ransack(params[:q]) || Customer.ransack(params[:last_contact])
      @customers = @q.result || @q.result.includes(:last_contact)
      @customers = @customers.last_mail_contact_trackings("送信済")
      @customers = @customers.distinct.preload(:last_contact).page(params[:page]).per(30)
    end
  
    def show
      @contact_trackings = ContactTracking.where(sender_id: params[:id])
      Rails.logger.info("sender : " + @sender.to_yaml)
       Rails.logger.info("@contact_trackings : " + @contact_trackings.to_yaml)
      @contact_trackings = @contact_trackings.page(params[:page]).per(30)
  
    end
  
    def edit
       Rails.logger.info("params : " + params[:id])
      @contact_tracking = ContactTracking.find(params[:id])
    end
  
    def update
      #@customers = Customer&.where(worker_id: current_worker.id)
      #@count_day = @customers.where('updated_at > ?', Time.current.beginning_of_day).where('updated_at < ?',Time.current.end_of_day).count
      @contact_tracking = ContactTracking.find(params[:id])
        if @contact_tracking.update_attribute(:status, @contact_tracking.status)
          #flash[:notice] = "登録が完了しました。1日あたりの残り作業実施件数は#{30 - @count_day}件です。"
          redirect_to sendlist_path(id: @contact_tracking.sender.id), notice:"ステータスが編集されました。"
        else
          render 'edit'
        end
    end
  
    private
  
  
      def authenticate_user_or_admin
        unless user_signed_in? || admin_signed_in?
           redirect_to new_user_session_path, alert: 'error'
        end
      end
  end