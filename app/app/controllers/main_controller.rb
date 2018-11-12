class MainController < ApplicationController
  before_action :check_user_login

  private
    def check_user_login
      unless user_signed_in?
        redirect_to new_user_session_url and return
      end
      @current_user = current_user
    end
end