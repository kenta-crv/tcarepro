# app/controllers/restart_controller.rb
class RestartController < ApplicationController
    require 'net/http'
    def restart
      uri = URI('http://tcare.pro/webhook/url')
      Net::HTTP.post(uri, {token: "YOUR_SECRET_TOKEN"}.to_json, "Content-Type" => "application/json")
      flash[:notice] = "再起動が完了しました。"
      redirect_to root_path
    end
  end
  