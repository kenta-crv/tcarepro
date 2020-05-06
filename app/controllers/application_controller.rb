class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  layout :layout_by_resource
  #before_action :set_user

  #def set_user
  #  @user = User.find(params[:id])
  #end

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
         admin_path(@admin.id)
      when User
         user_path(@user.id)
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
      else
        super
      end
    end

  # Layout per resource_name
  def layout_by_resource
    if devise_controller? && resource_name == :admin
        "admins"
    elsif devise_controller? && resource_name == :user
        "users"
    else
      "application"
    end
  end

  def layout_by_resource
    if devise_controller?
      "application"
    end
  end

  #before_action :authenticate_user_or_admin

  #private
  #  def authenticate_user_or_admin
  #    unless user_signed_in? || admin_signed_in?
  #       redirect_to root_path, alert: 'error'
  #    end
  #  end

end
