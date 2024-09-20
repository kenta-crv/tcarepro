# class NotificationsController < ApplicationController
#     # トークン取得メソッド
#     def get_access_token
#     # ここにBearerトークンを取得するロジックを入れる
#         return FCMService.get_access_token
#     end
    
#     def create
#     token = get_access_token # Bearerトークンを取得
#     device_token = params[:token] # クライアントから指定されたデバイストークン
    
#     url = "https://fcm.googleapis.com/v1/projects/smart-edee0/messages:send"
    
#     response = RestClient.post(url, {
#     message: {
#     token: device_token,
#     notification: {
#     title: "Your Title",
#     body: "Your Message"
#     },
#     data: {
#     telephone: "1234567890",
#     date: Time.now.to_i
#     }
#     }
#     }.to_json, {
#     Authorization: "Bearer #{token}",
#     content_type: :json,
#     accept: :json
#     })
    
#     render json: response.body, status: response.code
#     end
# end

require 'net/http'
require 'uri'

class NotificationsController < ApplicationController

    def create
        # Bearerトークンを取得
        token = FCMService.get_access_token
        device_token = params[:token] # フロントエンドからのデバイストークン
        telephone = params[:telephone] # フロントエンドからの電話番号

        # FCMのAPIのURL
        url = URI.parse("https://fcm.googleapis.com/v1/projects/smart-edee0/messages:send")

        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true

        # POSTリクエストの設定
        request = Net::HTTP::Post.new(url)
        request["Authorization"] = "Bearer #{token}"
        request["Content-Type"] = "application/json"

        # リクエストボディの設定
        request.body = {
            message: {
                token: device_token,
                notification: {
                    title: "push",
                    body: "new message"
                    # priority: "high",
                    # time_to_live: 1
                },
                data: {
                    telephone: telephone,
                    date: String(Time.now.to_i)
                }
            }
        }.to_json

        # リクエストを送信
        response = http.request(request)

        # レスポンスを返す
        render json: response.body, status: response.code
        rescue StandardError => e
            render json: { error: e.message }, status: :internal_server_error
        end
    end