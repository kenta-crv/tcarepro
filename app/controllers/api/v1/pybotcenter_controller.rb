require 'date'

class Api::V1::PybotcenterController < ApplicationController

    skip_before_action :verify_authenticity_token

    def success
        Rails.logger.info("success!!")
        Rails.logger.info("generation_code ⇨ " + params[:generation_code])
        @data = ContactTracking.find_by(auto_job_code:params[:generation_code])
        @data.status = "送信済"
        @data.inquiry_id = params[:inquiry_id]
        if @data.save == true
            Rails.logger.info("データセーブをしました。")
            Rails.logger.info(@data.status + "です。")
        else
            Rails.logger.info("セーブエラーです。")
        end
        render status: 200, json: {data: 'success'}
    end

    def failed
        Rails.logger.info("failed!!")
        Rails.logger.info("generation_code ⇨ " + params[:generation_code])
        @data = ContactTracking.find_by(auto_job_code:params[:generation_code])
        @data.status = "自動送信エラー"
        @data.inquiry_id = params[:inquiry_id]
        if @data.save == true
            Rails.logger.info("データセーブをしました。")
            Rails.logger.info(@data.status + "です。")
        else
            Rails.logger.info("セーブエラーです。")
        end
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
