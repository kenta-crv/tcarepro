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
        Pynotify.create(title:params[:title],message:params[:message],status:params[:status],sended_at:DateTime.now)
        render status: 200, json: {void: "void"}
    end

    def graph_register
        Rails.logger.info("@pybots : グラフを登録します。")
        @gcode = params[:generate_code]
        p_success = params[:success_sent]
        p_failed = params[:failed_sent]
        @contra = ContactTracking.where(auto_job_code:params[:generate_code]).first
        customer_id = @contra.customer_id
        sender_id = @contra.sender_id
        worker_id = @contra.worker_id
        AutoformResult.create(customer_id:customer_id,sender_id:sender_id,worker_id:worker_id,success_sent:p_success,failed_sent:p_failed)
    end

    def get_inquiry
        @set = Inquiry.find(params[:id])
        render status: 200, json: {inquiry_data: @set}
    end
end
