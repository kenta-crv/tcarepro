require 'contactor'
require 'securerandom'
require 'json'

class OkuriteController < ApplicationController
  before_action :authenticate_worker_or_admin!, except: [:callback, :direct_mail_callback, :stats]
  before_action :set_sender, except: [:callback, :direct_mail_callback, :stats]
  before_action :set_customers, only: [:preview]

  rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found

  def index
    # この`sender`に紐づく全ての`ContactTracking`をベースとして取得
    base_contact_trackings = ContactTracking.for_sender(@sender.id)

    # 条件分岐1: 一括設定直後（IDの配列が渡された場合）
    # autosettingsアクションからリダイレクトされた際の、最も優先されるべき特殊な表示処理
    if params[:q]&.dig(:contact_trackings_id_in).present?
      # Ransackの検索オブジェクトを生成（検索フォームの状態を維持するため）
      @q = Customer.ransack(params[:q])
      
      # 渡されたIDを持つContactTrackingに紐づくCustomerを、更新が新しい順に取得
      @customers = Customer.joins(:contact_trackings)
                           .where(contact_trackings: { id: params[:q][:contact_trackings_id_in] })
                           .order('contact_trackings.updated_at DESC')
                           .page(params[:page]).per(30)

    # 条件分岐2: 検索モーダルで「状態」が指定された場合
    elsif params[:q]&.dig(:contact_trackings_status_eq).present?
      status = params[:q][:contact_trackings_status_eq]
      
      # パフォーマンスのため、各顧客の最新のContactTrackingレコードIDのみを取得
      latest_ids = base_contact_trackings.select('MAX(id) as id').group(:customer_id)
      # 最新レコードの中から、指定されたステータスを持つ顧客IDを絞り込む
      customer_ids = base_contact_trackings.where(id: latest_ids).where(status: status).select(:customer_id)
      
      @q = Customer.where(id: customer_ids).ransack(params[:q])

      # 「自動送信予定」の場合は、特別に更新順でソートする
      if status == '自動送信予定'
        @customers = @q.result.distinct
                    .joins(:contact_trackings)
                    .where(contact_trackings: {sender_id: @sender.id, status: '自動送信予定'})
                    .order('contact_trackings.updated_at DESC')
                    .page(params[:page]).per(30)
      else
        @customers = @q.result.distinct.order(:id).page(params[:page]).per(30)
      end

    # 条件分岐3: 検索モーダルで「未送信」がチェックされた場合
    elsif params[:q]&.dig(:contact_tracking_id_null).present? && params[:q][:contact_tracking_id_null] == 'true'
      # 一度でもコンタクト履歴がある顧客IDを除外する
      contacted_customer_ids = base_contact_trackings.select(:customer_id)
      @q = Customer.where.not(id: contacted_customer_ids).ransack(params[:q])
      @customers = @q.result.distinct.order(:id).page(params[:page]).per(30)

    # 条件分岐4: 上記以外の全てのケース（通常のページアクセス時）
    else
      @q = Customer.ransack(params[:q])
      @customers = @q.result.distinct.order(:id).page(params[:page]).per(30)
    end
    
    # パフォーマンス対策: 画面に表示する顧客のContactTracking情報を一括で取得し、N+1問題を回避する
    customer_ids_on_page = @customers.pluck(:id)
    @contact_trackings_hash = base_contact_trackings
                              .where(customer_id: customer_ids_on_page)
                              .includes(:customer, :worker, :inquiry)
                              .group_by(&:customer_id)
  end
  
  def show
    @customer = Customer.find(params[:id])
  end

  def stats
    # Set sender if sender_id is provided
    if params[:sender_id].present?
      @sender = Sender.find(params[:sender_id])
      # Calculate overall success rate for this sender
      @success_count = ContactTracking.where(sender_id: @sender.id, status: '送信済').count
      @total_count = ContactTracking.where(sender_id: @sender.id).where.not(status: ['自動送信予定', '処理中']).count
      
      # Get recent submissions for this sender (exclude scheduled ones)
      @recent_submissions = ContactTracking.includes(:customer)
                                        .where(sender_id: @sender.id)
                                        .where.not(status: ['自動送信予定', '処理中'])
                                        .order(created_at: :desc)
                                        .limit(10)
    else
      # Calculate overall success rate for all senders
      @success_count = ContactTracking.where(status: '送信済').count
      @total_count = ContactTracking.where.not(status: ['自動送信予定', '処理中']).count
      
      # Get recent submissions for all senders (exclude scheduled ones)
      @recent_submissions = ContactTracking.includes(:customer)
                                        .where.not(status: ['自動送信予定', '処理中'])
                                        .order(created_at: :desc)
                                        .limit(10)
    end

    # Calculate daily statistics for the past 7 days (only completed ones)
    @daily_stats = {}
    6.downto(0) do |i|
      date = i.days.ago.to_date
      if @sender
        day_trackings = ContactTracking.where(sender_id: @sender.id, created_at: date.all_day)
                                      .where.not(status: ['自動送信予定', '処理中'])
      else
        day_trackings = ContactTracking.where(created_at: date.all_day)
                                      .where.not(status: ['自動送信予定', '処理中'])
      end
      @daily_stats[date.strftime('%Y-%m-%d')] = {
        success: day_trackings.where(status: '送信済').count,
        total: day_trackings.count
      }
    end
    
    # Explicitly render the template to fix the "missing template" error
    render 'stats'
  end

  def preview
    @customer = Customer.find(params[:okurite_id])
    
    # Inquiry（問い合わせ文）の取得。Nilの場合はフォールバックし、それでもなければエラーで処理を中断
    @inquiry = @sender.default_inquiry || Inquiry.first
    if @inquiry.nil?
      flash[:alert] = "問い合わせ文が設定されていません。システム管理者に連絡してください。"
      redirect_to sender_okurite_index_path(@sender) and return
    end
    
    @q = Customer.ransack(params[:q])
    @customers = @q.result(distinct: true)

    # ページネーション用の「前へ」「次へ」の顧客情報を取得
    @prev_customer = @customers.where("customers.id < ?", @customer.id).reorder(id: :desc).first
    @next_customer = @customers.where("customers.id > ?", @customer.id).reorder(id: :asc).first

    # この顧客に対する最新のコンタクト履歴を取得（更新日時が新しいものを優先）
    @contact_tracking = ContactTracking.for_sender(@sender.id)
                                       .where(customer: @customer)
                                       .order(updated_at: :desc, id: :desc)
                                       .first
    
    contactor = Contactor.new(@inquiry, @sender)
    
    # プレビュー画面で実際に使用するURLを決定（履歴のURLを優先）
    @contact_url = @contact_tracking&.contact_url.presence || @customer.contact_url
    
    @callback_code = @sender.generate_code
    gon.typings = contactor.try_typings(@contact_url, @customer.id)
  end

  def create
    # プレビュー画面からの手動ステータス更新処理
    # 既存のContactTrackingレコードを検索、なければ新規作成の準備
    @contact_tracking = ContactTracking.for_sender(@sender.id)
                                       .find_or_initialize_by(customer_id: params[:okurite_id])

    # 更新または新規作成する属性をハッシュとして準備
    attributes = {
      status: params[:status], # フォームから送信されたステータスを使用
      worker_id: current_worker&.id,
      contact_url: params[:contact_url],
      code: params[:callback_code] || @contact_tracking.code || SecureRandom.hex(10),
      inquiry_id: params[:inquiry_id] || @sender.default_inquiry_id
    }

    # ステータスが「送信済」の場合に限り、送信日時(sended_at)を更新する
    if params[:status] == '送信済'
      attributes[:sended_at] = Time.current
    end

    # バリデーションを実行しつつレコードを保存
    @contact_tracking.update!(attributes)

    # --- ここからがリダイレクト処理の修正 ---

    # 次の顧客IDがパラメータに含まれている場合（リストを順番に処理している場合）
    if params[:next_customer_id].present?
      redirect_to sender_okurite_preview_path(
        okurite_id: params[:next_customer_id],
        q: params[:q]&.permit!
      )
    else
      # 次の顧客がいない場合（単一のレコードを更新した場合）は、
      # 同じプレビュー画面に、更新完了メッセージと共にリダイレクトする
      flash[:notice] = "ステータスを「#{params[:status]}」に更新しました。"
      redirect_to sender_okurite_preview_path(
        okurite_id: params[:okurite_id], # 今いる顧客IDを渡す
        q: params[:q]&.permit!
      )
    end

  # バリデーションエラーやその他の例外をここで捕捉
  rescue ActiveRecord::RecordInvalid => e
    error_messages = e.record.errors.full_messages.join(', ')
    redirect_back fallback_location: sender_okurite_path(@sender),
                  alert: "更新に失敗しました: #{error_messages}"
  rescue => e
    redirect_back fallback_location: sender_okurite_path(@sender),
                  alert: "更新に失敗しました: #{e.message}"
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

  # Update the autosettings method to properly handle URL validation
  def autosettings
    Rails.logger.info("autosettings called. Date: #{params[:date]}, Count: #{params[:count]}")

    @q = Customer.ransack(params[:q])
    
    target_count = params[:count].to_i
    @customers = @q.result.distinct.limit(target_count * 3)
    
    Rails.logger.info("OkuriteController: 対象顧客数: #{@customers.count}件")
    
    save_cont = 0
    @sender = Sender.find(params[:sender_id])
    processed_contact_tracking_ids = []

    # Date parsing
    begin
      parsed_scheduled_date = Time.zone.parse(params[:date])
      if parsed_scheduled_date.nil?
        raise ArgumentError, "Invalid date format"
      end
    rescue ArgumentError, TypeError
      Rails.logger.error "OkuriteController: Invalid date format received in autosettings: '#{params[:date]}'"
      redirect_to sender_okurite_index_path(sender_id: @sender.id, q: params[:q]&.permit!), alert: "無効な日付形式です。"
      return
    end

    processed_count = 0
    @customers.each do |cust|
      processed_count += 1
      break if target_count <= save_cont

      # Use the customer's contact_url directly instead of get_search_url
      url_to_submit = cust.contact_url.presence

      # Skip if no URL or invalid URL
      unless url_to_submit.present? && (!url_to_submit.start_with?('http://') && !url_to_submit.start_with?('https://'))
        Rails.logger.warn "OkuriteController: Skipping Customer ID #{cust.id} due to invalid URL: #{url_to_submit}"
        next
      end

      # Find or create contact tracking
      contact_tracking = ContactTracking.find_or_initialize_by(
        customer_id: cust.id,
        sender_id: @sender.id
      )

      # Skip if already processed with final status
      if contact_tracking.persisted? && ['送信済', '自動送信エラー'].include?(contact_tracking.status)
        Rails.logger.info "OkuriteController: Skipping already processed Customer ID #{cust.id} with status: #{contact_tracking.status}"
        next
      end

      # Update attributes
      contact_tracking.assign_attributes(
        contact_url: url_to_submit,
        customers_code: cust.customers_code,
        status: '自動送信予定',
        scheduled_date: parsed_scheduled_date,
        code: SecureRandom.hex(10),
        auto_job_code: "session_#{Time.now.to_i}_#{SecureRandom.hex(4)}",
        inquiry_id: @sender.default_inquiry_id || Inquiry.first&.id # Fallback to first inquiry
      )

      if contact_tracking.save
        processed_contact_tracking_ids << contact_tracking.id
        
        # Schedule the job
        AutoformSchedulerWorker.perform_async(contact_tracking.id)
        
        save_cont += 1
        Rails.logger.info "OkuriteController: Scheduled job for ContactTracking ID #{contact_tracking.id} with URL: #{url_to_submit}"
      else
        Rails.logger.error "OkuriteController: Failed to save ContactTracking for Customer ID #{cust.id}: #{contact_tracking.errors.full_messages}"
      end
    end

    Rails.logger.info("OkuriteController: Total jobs scheduled: #{save_cont}")

    if save_cont > 0
      redirect_to sender_okurite_index_path(
        sender_id: @sender.id,
        q: { contact_trackings_id_in: processed_contact_tracking_ids }
      ), notice: "#{save_cont}件の自動送信を予約しました。"
    else
      redirect_to sender_okurite_index_path(
        sender_id: @sender.id
      ), alert: "自動送信予約する対象の顧客が見つかりませんでした。コンタクトURLが設定されている顧客を確認してください。"
    end
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