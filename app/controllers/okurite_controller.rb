require 'contactor'
require 'securerandom'
require 'json'

class OkuriteController < ApplicationController
  before_action :authenticate_worker_or_admin!, except: [:callback,:direct_mail_callback]
  before_action :set_sender, except: [:callback,:direct_mail_callback]
  before_action :set_customers, only: [:index, :preview]

  def index
    # OK: contact_trackings もEagerLoadし、検索対象に含める
    @q = Customer.includes(:contact_trackings).ransack(params[:q])
  
    # ransackで絞り込んだ結果
    @customers = @q.result.distinct.page(params[:page]).per(30)
  
    # 既存の forever: nil 条件をどうしても追加したいなら、
    # merge する書き方でもOK
    # conditional_results = Customer.where(forever: nil)
    # @customers = @customers.merge(conditional_results)
  
    # ContactTracking 一覧を取得
    @contact_trackings = ContactTracking.latest(@sender.id).where(customer_id: @customers.select(:id)) # ここを追加
  end
  
  
  def resend
    customers = Customer.joins(:contact_trackings)
                        .where(contact_trackings: { sender_id: params[:sender_id], status: '送信済' })
                        .distinct
    @q = customers.ransack(params[:q])
    @customers = @q.result.page(params[:page]).per(30)
    @contact_trackings = ContactTracking.latest(params[:sender_id]).where(customer_id: @customers.pluck(:id))
  end
  
  def show
    @customer = Customer.find(params[:id])
  end

  def create
    @sender.send_contact!(
      params[:callback_code],
      params[:okurite_id],
      current_worker&.id,
      params[:inquiry_id],
      params[:contact_url],
      params[:status]
    )

    if params[:next_customer_id].present?
      redirect_to sender_okurite_preview_path(
        okurite_id: params[:next_customer_id],
        q: params[:q]&.permit!
      )
    else
      flash[:notice] = "送信が完了しました"

      redirect_to sender_okurite_index_path(sender_id: sender.id)
    end
  end

  def preview
    @customer = Customer.find(params[:okurite_id])
    @inquiry = @sender.default_inquiry
    @q = Customer.ransack(params[:q])
    @customers = @q.result(distinct: true)
  
    @prev_customer = @customers.where("customers.id < ?", @customer.id).last
    @next_customer = @customers.where("customers.id > ?", @customer.id).first
    @contact_tracking = @sender.contact_trackings.where(customer: @customer).order(created_at: :desc).first
  
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
      
      # Delete all contact_trackings with status '自動送信予定' for this sender
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
    
    # Redirect back to the referring page
    redirect_back(fallback_location: sender_okurite_index_path(sender))
  end

  def autosettings
    Rails.logger.info("autosettings called. Date: #{params[:date]}, Count: #{params[:count]}")
    @q = Customer.ransack(params[:q])
    @customers = @q.result.distinct
    save_cont = 0
    @sender = Sender.find(params[:sender_id]) # Ensure @sender is set correctly

    scheduled_date_str = params[:date]
    parsed_scheduled_date = nil

    begin
      parsed_scheduled_date = Time.zone.parse(scheduled_date_str)
      if parsed_scheduled_date.nil? # Time.zone.parse can return nil for invalid formats
        raise ArgumentError, "Invalid date format"
      end
    rescue ArgumentError, TypeError
      Rails.logger.error "OkuriteController: Invalid date format received in autosettings: '#{scheduled_date_str}'"
      redirect_to sender_okurite_index_path(sender_id: @sender.id, q: params[:q]&.permit!, page: params[:page]), alert: "無効な日付形式です。"
      return
    end

    @customers.each do |cust|
      break if params[:count].to_i <= save_cont

      # --- Create a new ContactTracking record for this auto-submission attempt ---
      # The AutoformSchedulerWorker will use the ID of this record.
      # The Python script will update this specific record.

      # Determine the contact_url. Ensure cust.get_search_url is reliable.
      # If cust.contact_url is the direct inquiry form URL, prefer that.
      # get_search_url might be a search result page, not the form itself.
      # This needs to match what the user expects to be submitted to.
      url_to_submit = cust.get_search_url 
      
      # Validate URL (basic check)
      unless url_to_submit.present? && url_to_submit.start_with?('http')
        Rails.logger.warn "OkuriteController: Skipping Customer ID #{cust.id} due to invalid or missing contact_url: '#{url_to_submit}'"
        next # Skip this customer
      end

      contact_tracking = ContactTracking.new(
        customer: cust,
        sender: @sender,
        # inquiry_id: @sender.default_inquiry_id, # The worker will fetch inquiry details based on its logic
        # Let's ensure the worker can derive the inquiry from sender or contact_tracking if needed.
        # If default_inquiry_id is crucial for the worker to find the right inquiry, set it.
        contact_url: url_to_submit,
        customers_code: cust.customers_code,
        status: '自動送信予定', # Initial status
        scheduled_date: parsed_scheduled_date,
        code: SecureRandom.hex(10), # For generation_code, if still used elsewhere
        auto_job_code: "session_#{Time.now.to_i}_#{SecureRandom.hex(4)}" # For session_code
      )
      contact_tracking.inquiry_id = @sender.default_inquiry_id 

      if contact_tracking.save
        begin
          # Enqueue the job to run ASAP or at the scheduled time
          if parsed_scheduled_date <= Time.zone.now
            AutoformSchedulerWorker.perform_async(contact_tracking.id)
          else
            AutoformSchedulerWorker.perform_at(parsed_scheduled_date, contact_tracking.id)
          end
          save_cont += 1
          Rails.logger.info "OkuriteController: Enqueued job for ContactTracking ID #{contact_tracking.id}, Customer ID #{cust.id}"
        rescue StandardError => e
          Rails.logger.error "OkuriteController: Failed to enqueue job for ContactTracking ID #{contact_tracking.id}. Error: #{e.message}"
          # Optionally, update contact_tracking status to an error state here if enqueuing fails
          contact_tracking.update(status: '自動送信システムエラー', notes: "Sidekiqへの登録に失敗: #{e.message.truncate(100)}")
        end
      else
        Rails.logger.error "OkuriteController: Failed to create ContactTracking for Customer ID #{cust.id}. Errors: #{contact_tracking.errors.full_messages.join(', ')}"
        # Optionally, collect these errors to display to the user
      end
    end

    Rails.logger.info("OkuriteController: Total jobs enqueued: #{save_cont}")
    redirect_to sender_okurite_index_path(sender_id: @sender.id, q: params[:q]&.permit!, page: params[:page]), notice: "#{save_cont}件の自動送信を予約しました。"
  end

  private

  def set_sender
    @sender = Sender.find(params[:sender_id])
  end

  def set_customers
    @q = Customer.ransack(params[:q])
    @customers = @q.result.distinct
  
    # URLの条件を追加
    #@customers = @customers.where.not("url LIKE ? OR url_2 LIKE ?", "%xn--pckua2a7gp15o89zb.com%", "%indeed.com/%")
  
    #if params[:statuses]&.map(&:presence)&.compact.present?
    ##  @customers = @customers.last_contact_trackings(@sender.id, params[:statuses])
    #end
  end

  def authenticate_worker_or_admin!
    unless worker_signed_in? || admin_signed_in?
      redirect_to new_worker_session_path, alert: 'error'
    end
  end
end
