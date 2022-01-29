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
  rescue_from ActiveRecord::RecordNotFound, with: :render_404
  rescue_from ActionController::RoutingError, with: :render_404
  #rescue_from Exception, with: :render_500

  def render_404
    render template: 'errors/error_404', status: 404, layout: 'application', content_type: 'text/html'
  end

  def render_500
    render template: 'errors/error_500', status: 500, layout: 'application', content_type: 'text/html'
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
        sender_path(current_sender)
      when Client
        client_path
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
      when Client, :client, :clients
        new_sender_client_path
      else
        super
      end
    end

  # Layout per resource_name
  # TODO: `layout_by_resource` メソッドがかぶっているので、このメソッドは不要に見える。不要なら消す。
  def layout_by_resource
    if devise_controller? && resource_name == :admin
        "admins"
    elsif devise_controller? && resource_name == :user
        "users"
    elsif devise_controller? && resource_name == :worker
        "workers"
    elsif devise_controller? && resource_name == :sender
        "senders"
    else
      "application"
    end
  end

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

end
