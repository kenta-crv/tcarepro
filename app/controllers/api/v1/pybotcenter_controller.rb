require 'date'

class Api::V1::PybotcenterController < ApplicationController

    skip_before_action :verify_authenticity_token

    def success
        Rails.logger.info("success!!")
        update_status("送信済")
        render status: 200, json: {data: 'success'}
    end

    def failed
        Rails.logger.info("failed!!")
        update_status("自動送信エラー")
        render status: 200, json: {data: 'failed'}
    end

    def notify_post
        Pynotify.create(title:params[:title],message:params[:message],status:params[:status],sended_at:DateTime.now)
        render status: 200, json: {void: "void"}
    end

    def graph_register
        Rails.logger.info("@pybots : グラフを登録します。")
        @contra = ContactTracking.find_by(auto_job_code:params[:generate_code])
        return unless @contra

        AutoformResult.create(
          customer_id: @contra.customer_id,
          sender_id: @contra.sender_id,
          worker_id: @contra.worker_id,
          success_sent: params[:success_sent],
          failed_sent: params[:failed_sent]
        )
    end

    def get_inquiry
        @set = Inquiry.find(params[:id])
        render status: 200, json: {inquiry_data: @set}
    end

    private

    def update_status(status)
        Rails.logger.info("generation_code ⇨ " + params[:generation_code])
        @data = ContactTracking.find_by(auto_job_code:params[:generation_code])
        return unless @data

        @data.status = status
        @data.inquiry_id = params[:inquiry_id]
        if @data.save
            Rails.logger.info("データセーブをしました。")
            Rails.logger.info(@data.status + "です。")
        else
            Rails.logger.info("セーブエラーです。")
        end
    end

end
