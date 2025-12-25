class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  layout :layout_by_resource
  #before_action :set_user
  before_action :current_user_to_js

  #def set_user
  #  @user = User.find(params[:id])
  #end

  def current_user_to_js
    if current_user.present?
      notified_call = params[:notified_call_id] && Call.find_by(id: params[:notified_call_id])

      calls = current_user.calls.joins(:customer).unread_notification.order(:time)

      if notified_call
        notified_call.latest_confirmed_time = Time.zone.now
        notified_call.save
        Rails.cache.delete(calls.cache_key)
      end

      gon.current_user = Rails.cache.fetch(calls.cache_key, expires_in: 1.minute) {
        calls.map do |call|
          {
            id: call.id,
            time: call.time,
            customer_id: call.customer_id,
            customer_name: call.customer.company,
          }
        end
      }
    else
      gon.current_user = []
    end
  end

# 例外処理
  # rescue_from ActiveRecord::RecordNotFound, with: :render_404
  # rescue_from ActionController::RoutingError, with: :render_404
  #rescue_from Exception, with: :render_500

  def render_404
    respond_to do |format|
      format.html { render template: 'errors/error_404', status: 404, layout: 'application' }
      format.json { render json: { error: 'Not found' }, status: 404 }
      format.any { render plain: '404 Not Found', status: 404 }
    end
  rescue ActionController::UnknownFormat
    render plain: '404 Not Found', status: 404
  end

  def render_500
    respond_to do |format|
      format.html { render template: 'errors/error_500', status: 500, layout: 'application' }
      format.json { render json: { error: 'Internal Server Error' }, status: 500 }
      format.any { render plain: '500 Internal Server Error', status: 500 }
    end
  rescue ActionController::UnknownFormat
    render plain: '500 Internal Server Error', status: 500
  end

  before_action :configure_permitted_parameters, if: :devise_controller?

  protected
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:user_name, :select])
  end

    # set for devise login redirector
    def after_sign_in_path_for(resource)
      case resource
      when Admin
         customers_path
      when User
         customers_path
      when Worker
        worker_path(current_worker)
      when Sender
        if current_sender.inquiries.empty?
          flash[:notice] = "案件の内容を登録してください"
          new_sender_inquiry_path(current_sender)
        else
          # Redirect to okurite list page (main page for senders)
          sender_okurite_index_path(current_sender)
        end
      else
        super
      end
    end

    def after_sign_out_path_for(resource)
      case resource
      when Admin, :admin, :admins
        new_admin_session_path
      when User, :user, :users
        new_user_session_path
      when Worker, :worker, :workers
        new_worker_session_path
      when Sender, :sender, :senders
        new_sender_session_path
      else
        super
      end
    end

  # Layout per resource_name
  def layout_by_resource
    if devise_controller?
      "application"
    end
  end

  #before_action :authenticate_user_or_admin"

  #private
  #  def authenticate_user_or_admin
  #    unless user_signed_in? || admin_signed_in?
  #       redirect_to root_path, alert: 'error'
  #    end
  #  end
  def set_current_worker_for_model
    # current_worker はログインしているworkerオブジェクトを返すメソッドを想定
    if current_worker.present?
      Thread.current[:current_worker_id] = current_worker.id
    end
    yield # アクションを実行
  ensure
    # アクション実行後、必ずクリアする
    Thread.current[:current_worker_id] = nil
  end
end
