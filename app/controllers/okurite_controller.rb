require 'contactor'
require 'securerandom'
require 'json'

class OkuriteController < ApplicationController
  before_action :authenticate_worker_or_admin!, except: [:callback, :direct_mail_callback]
  before_action :set_sender, except: [:callback, :direct_mail_callback]
  before_action :set_customers, only: [:preview]

  rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found

  def index
    # sender_idでContactTrackingを制限した上でCustomer検索
    base_contact_trackings = ContactTracking.for_sender(@sender.id)
  
    # ステータス検索がある場合の特別処理
    if params[:q]&.dig(:contact_trackings_status_eq).present?
      # 指定されたステータスのContactTrackingに関連するCustomerのみを対象
      customer_ids = base_contact_trackings.where(status: params[:q][:contact_trackings_status_eq]).select(:customer_id)
    
      # Customer検索の範囲をsender関連の顧客に限定
      @q = Customer.where(id: customer_ids).ransack(params[:q])
    elsif params[:q]&.dig(:contact_tracking_id_null).present? && params[:q][:contact_tracking_id_null] == 'true'
      # 未送信検索の場合：このSenderでContactTrackingがない顧客を検索
      contacted_customer_ids = base_contact_trackings.select(:customer_id)
      @q = Customer.where.not(id: contacted_customer_ids).ransack(params[:q])
    else
      # 通常の検索
      @q = Customer.ransack(params[:q])
    end

    @customers = @q.result.distinct.page(params[:page]).per(30)
    
    # ContactTrackingは常にsender_id制限下で取得
    @contact_trackings = base_contact_trackings.where(customer_id: @customers.select(:id))
                          .includes(:customer, :worker, :inquiry)
                          .order(created_at: :desc)
end
  
  def resend
    # sender_idを強制的に注入
    sanitized_params = build_secure_search_params
    sanitized_params.merge!(status_eq: '送信済')
    @q = ContactTracking.ransack(sanitized_params)
    @contact_trackings = @q.result
                          .includes(:customer, :worker, :inquiry)
                          .order(created_at: :desc)
                          .page(params[:page])
                          .per(30)
    @customers = Customer.where(id: @contact_trackings.select(:customer_id)).distinct
  end
  
  def show
    @customer = Customer.find(params[:id])
  end

  def create
    if params[:status] == '送信済'
      # 手動「送信済み」更新の場合
      @contact_tracking = ContactTracking.for_sender(@sender.id)
                                        .where(customer_id: params[:okurite_id])
                                        .first
      
      if @contact_tracking
        # 既存レコードを直接更新（バリデーション回避）
        @contact_tracking.update_columns(
          status: '送信済',
          sended_at: Time.current,
          worker_id: current_worker&.id,
          contact_url: params[:contact_url],
          code: params[:callback_code],
          updated_at: Time.current
        )
      else
        # レコードがない場合は新規作成
        ContactTracking.create!(
          customer_id: params[:okurite_id],
          sender_id: @sender.id,
          worker_id: current_worker&.id,
          inquiry_id: params[:inquiry_id],
          contact_url: params[:contact_url],
          status: '送信済',
          sended_at: Time.current,
          code: params[:callback_code],
          auto_job_code: @sender.generate_code
        )
      end
    else
      # 通常の送信処理
      @sender.send_contact!(
        params[:callback_code],
        params[:okurite_id],
        current_worker&.id,
        params[:inquiry_id],
        params[:contact_url],
        params[:status]
      )
    end

    # リダイレクト処理
    if params[:next_customer_id].present?
      redirect_to sender_okurite_preview_path(
      okurite_id: params[:next_customer_id],
      q: params[:q]&.permit!
    )
    else
      flash[:notice] = "送信が完了しました"
      redirect_to sender_okurite_index_path(sender_id: @sender.id)
    end
  rescue => e
    redirect_back fallback_location: sender_okurite_path(@sender),
    alert: "更新に失敗しました: #{e.message}"
  end
    
  def preview
    @customer = Customer.find(params[:okurite_id])
    @inquiry = @sender.default_inquiry
    @q = Customer.ransack(params[:q])
    @customers = @q.result(distinct: true)
  
    @prev_customer = @customers.where("customers.id < ?", @customer.id).last
    @next_customer = @customers.where("customers.id > ?", @customer.id).first
    @contact_tracking = ContactTracking.for_sender(@sender.id)
                                  .where(customer: @customer)
                                  .order(updated_at: :desc, id: :desc)
                                  .first
    contactor = Contactor.new(@inquiry, @sender)
    @contact_url = @customer.contact_url
    @callback_code = @sender.generate_code
    gon.typings = contactor.try_typings(@contact_url, @customer.id)
  end
  
  def callback
    @contact_tracking = ContactTracking.find_by!(code: params[:t])
    @contact_tracking.callbacked_at = Time.zone.now
    @contact_tracking.save
    redirect_to @contact_tracking.inquiry.url
  end

  def direct_mail_callback
    Rails.logger.info( "inside direct mail callback : ")
    @direct_mail_contact_tracking = DirectMailContactTracking.find_by!(code: params[:t])
    @direct_mail_contact_tracking.callbacked_at = Time.zone.now
    @direct_mail_contact_tracking.save
    redirect_to "https://ri-plus.jp/"
  end

  def okurite_new_status(customer, status)
    Rails.logger.info( "@sender : " + status + 'に設定')
    customer.contact_trackings.each do |contact_tracking|
      contact_tracking.status = '自動送信予定'
      contact_tracking.save!
    end
  end

  def bulk_delete
    begin
      sender = current_sender || Sender.find(params[:sender_id])
      
      deleted_count = ContactTracking.joins(:inquiry)
                                    .where(inquiries: { sender_id: sender.id })
                                    .where(status: '自動送信予定')
                                    .delete_all
      
      if deleted_count > 0
        flash[:notice] = "#{deleted_count}件の自動送信予定を削除しました。"
      else
        flash[:alert] = "削除対象の自動送信予定が見つかりませんでした。"
      end
      
    rescue => e
      Rails.logger.error "Bulk delete error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      flash[:alert] = "削除中にエラーが発生しました: #{e.message}"
    end
    
    redirect_back(fallback_location: sender_okurite_index_path(sender))
  end

  def autosettings
    Rails.logger.info("autosettings called. Date: #{params[:date]}, Count: #{params[:count]}")

    @q = Customer.ransack(params[:q])
    
    # 🔥 重要な修正：処理件数を大幅に制限
    target_count = params[:count].to_i
    # 必要な件数の3倍程度に制限（送信済みをスキップする可能性があるため）
    @customers = @q.result.distinct.limit(target_count * 3)
    
    Rails.logger.info("OkuriteController: 対象顧客数: #{@customers.count}件")
    
    save_cont = 0
    @sender = Sender.find(params[:sender_id])

    scheduled_date_str = params[:date]
    parsed_scheduled_date = nil

    begin
      parsed_scheduled_date = Time.zone.parse(scheduled_date_str)
      if parsed_scheduled_date.nil?
        raise ArgumentError, "Invalid date format"
      end
    rescue ArgumentError, TypeError
      Rails.logger.error "OkuriteController: Invalid date format received in autosettings: '#{scheduled_date_str}'"
      redirect_to sender_okurite_index_path(sender_id: @sender.id, q: params[:q]&.permit!, page: params[:page]), alert: "無効な日付形式です。"
      return
    end

    processed_count = 0
    @customers.each do |cust|
      processed_count += 1
      
      # 進捗ログ（5件ごと）
      if processed_count % 5 == 0
        Rails.logger.info "OkuriteController: 処理進捗 #{processed_count}/#{@customers.count} (成功: #{save_cont})"
      end
      
      # 目標件数に達したら終了
      break if target_count <= save_cont

      url_to_submit = cust.get_search_url

      unless url_to_submit.present? && url_to_submit.start_with?('http')
        Rails.logger.warn "OkuriteController: Skipping Customer ID #{cust.id} due to invalid or missing contact_url: '#{url_to_submit}'"
        next
      end

      # 既存レコードを検索または新規初期化（ユニーク制約回避）
      contact_tracking = ContactTracking.find_or_initialize_by(
        customer_id: cust.id,
        sender_id: @sender.id
      )

      # 既存レコードの場合は状態を確認
      if contact_tracking.persisted?
        # 既に送信済みまたは送信予定の場合はスキップ
        if ['送信済', '自動送信予定', '処理中'].include?(contact_tracking.status)
          Rails.logger.info "OkuriteController: Skipping Customer ID #{cust.id} - already processed (#{contact_tracking.status})"
          next
        end
      end

      # 属性を設定
      contact_tracking.assign_attributes(
        contact_url: url_to_submit,
        customers_code: cust.customers_code,
        status: '自動送信予定',
        scheduled_date: parsed_scheduled_date,
        code: SecureRandom.hex(10),
        auto_job_code: "session_#{Time.now.to_i}_#{SecureRandom.hex(4)}",
        inquiry_id: @sender.default_inquiry_id
      )

      if contact_tracking.save
        begin
          if parsed_scheduled_date <= Time.zone.now
            AutoformSchedulerWorker.perform_async(contact_tracking.id)
          else
            AutoformSchedulerWorker.perform_at(parsed_scheduled_date, contact_tracking.id)
          end

          save_cont += 1
          Rails.logger.info "OkuriteController: Enqueued job for ContactTracking ID #{contact_tracking.id}, Customer ID #{cust.id} (#{save_cont}/#{target_count})"
        rescue StandardError => e
          Rails.logger.error "OkuriteController: Failed to enqueue job for ContactTracking ID #{contact_tracking.id}. Error: #{e.message}"
          contact_tracking.update(status: '自動送信システムエラー', response_data: "Sidekiqへの登録に失敗: #{e.message.truncate(100)}")
        end
      else
        Rails.logger.error "OkuriteController: Failed to save ContactTracking for Customer ID #{cust.id}. Errors: #{contact_tracking.errors.full_messages.join(', ')}"
      end
    end

    Rails.logger.info("OkuriteController: Total jobs enqueued: #{save_cont}")
    redirect_to sender_okurite_index_path(sender_id: @sender.id, q: params[:q]&.permit!, page: params[:page]), notice: "#{save_cont}件の自動送信を予約しました。"
  end


  private

  def build_secure_search_params
    sanitized = params[:q]&.except(:sender_id_eq, :contact_trackings_sender_id_eq) || {}
    # ContactTrackingの検索時にsender_id制限を強制注入
    if sanitized[:contact_trackings_status_eq].present?
      sanitized[:contact_trackings_sender_id_eq] = @sender.id
    end
    sanitized
  end

  def set_sender
    @sender = Sender.find(params[:sender_id])
  end

  def set_customers
    @q = Customer.ransack(params[:q])
    @customers = @q.result.distinct
  end

  def handle_validation_error(exception)
    error_messages = exception.record.errors.full_messages.join(', ')
    redirect_back fallback_location: sender_okurite_path(@sender),
                  alert: "更新に失敗しました: #{error_messages}"
  end

  def handle_record_not_found(exception)
    redirect_to sender_okurite_index_path(@sender), alert: 'レコードが見つかりません'
  end

  def authenticate_worker_or_admin!
    unless worker_signed_in? || admin_signed_in?
      redirect_to new_worker_session_path, alert: 'error'
    end
  end
end