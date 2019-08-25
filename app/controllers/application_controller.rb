class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  layout :layout_by_resource

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



      private
    # set for devise login redirector
    def after_sign_in_path_for(resource)
      case resource
      when Admin
        super # 現在は暫定的に上位継承しています
       root_path
      end
    end

    def after_sign_out_path_for(resource)
      case resource
      when Admin, :admin, :admins
        new_admin_session_path
        # put here for Staff default page direct path after signed out
      else
        super
      end
    end

  # Layout per resource_name
  def layout_by_resource
    if devise_controller? && resource_name == :admin
        "admins"
    else
      "application"
    end
  end

  def layout_by_resource
    if devise_controller?
      "application"
    end
  end



end
