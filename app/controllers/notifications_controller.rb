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
require 'json'

class NotificationsController < ApplicationController

    def create
        Rails.logger.info("notifications: " + Time.now.to_i.to_s)
        # Bearerトークンを取得
        access_token = get_access_token
        device_token = params[:token] # フロントエンドからのデバイストークン
        telephone = params[:telephone] # フロントエンドからの電話番号

        Rails.logger.info("device_token: #{device_token}, telephone: #{telephone}, access_token: #{access_token}")


        # FCMのAPIのURL
        url = URI("https://fcm.googleapis.com/v1/projects/smart-edee0/messages:send")

        
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true

        
        # POSTリクエストの設定
        request = Net::HTTP::Post.new(url.path, {
            "Content-Type" => "application/json",
            "Authorization" => "Bearer #{access_token}"
        })

        payload = {
            message: {
                token: device_token,
                notification: {
                    title: "push",
                    body: "new message"
                    # priority: "high",
                    # time_to_live: 1
                },
                data: {
                    "telephone": telephone,
                    "date": String(Time.now.to_i)
                }
            }
        }


        # リクエストボディの設定
        request.body = payload.to_json

        # # リクエストを送信
        response = http.request(request)

        # render json: { status: 'SUCCESS', message: 'OK', data: {access_token: access_token, device_token: device_token, telephone: telephone, body: response.body} }

        if response.is_a?(Net::HTTPSuccess)
            render json: response.body, status: :ok
        else
            Rails.logger.info("FCM response error: #{response.body}")
            render json: { error: response.body }, status: response.code
        end
        
        # # レスポンスを返す
        # render json: response.body, status: response.code
        # rescue StandardError => e
        #     render json: { error: e.message }, status: :internal_server_error
    end

    def get_access_token
        scope = 'https://www.googleapis.com/auth/firebase.messaging'
        service_account_file = Rails.root.join('config/smart-edee0-firebase-adminsdk-m74sr-92f564d81e.json')
        
        authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
          json_key_io: File.open(service_account_file),
          scope: scope
        )
        
        authorizer.fetch_access_token!['access_token']
    end
end
