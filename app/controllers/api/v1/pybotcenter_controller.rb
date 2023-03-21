require 'date'

class Api::V1::PybotcenterController < ApplicationController

    skip_before_action :verify_authenticity_token

    def success
        Rails.logger.info("success!!")
        @data = ContactTracking.where(auto_job_code:params[:generation_code]).first
        @data.update(status: "送信済")
        render status: 200, json: {data: 'success'}
    end

    def failed
        Rails.logger.info("failed!!")
        @data = ContactTracking.where(auto_job_code:params[:generation_code]).first
        @data.update(status: "自動送信エラー")
        render status: 200, json: {data: 'failed'}
    end

    def notify_post
        Rails.logger.info("PyNotify")
        Pynotify.create(title:params[:title],message:params[:message],status:params[:status],sended_at:DateTime.now)
        render status: 200, json: {void: "void"}
    end

    def get_inquiry
        @set = Inquiry.find(params[:id])
        render status: 200, json: {inquiry_data: @set}
    end
end
