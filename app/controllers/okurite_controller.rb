require 'contactor'
require 'securerandom'
require 'json'

class OkuriteController < ApplicationController
  before_action :authenticate_worker_or_admin!, except: [:callback,:direct_mail_callback]
  before_action :set_sender, except: [:callback,:direct_mail_callback]
  before_action :set_customers, only: [:preview]

  def index
    _contact_trackings = { sender_id: @sender.id } 
    _contact_trackings[:status] = params[:statuses] if params[:statuses].present?
    @q = Customer.eager_load(:contact_trackings)
                 .where(contact_trackings: _contact_trackings)
                 .where(forever: nil)
                 .with_company(params[:company_cont])
                 .with_tel(params[:tel_cont])
                 .with_address(params[:address_cont_any])
                 .with_is_contact_tracking(params[:contact_tracking_id_null])
                 .with_business(params[:business_cont])
                 .with_genre(params[:genre_cont])
                 .with_choice(params[:choice_cont])
                 .with_industry(params[:industry_cont])
                 .with_created_at(params[:created_at_gteq], params[:created_at_lteq])
                 .with_contact_tracking_sended_at(params[:contact_tracking_sended_at_gteq], params[:contact_tracking_sended_at_lteq])                           
                 .ransack(params[:q])
    @customers = @q.result.page(params[:page]).per(100)
    @contact_trackings = ContactTracking.where(sender_id:@sender.id,worker_id:current_worker.id)
    #Rails.logger.info("@contact_trackings : " + @contact_trackings.to_yaml)
  end

  def show
    @customer = Customer.find(params[:id])
  end

  def create
    if params[:forever_flag].present?
      customer = Customer.find(params[:okurite_id])
      customer.update(forever: params[:forever])
    else
      @sender.send_contact!(
        params[:callback_code],
        params[:okurite_id],
        current_worker&.id,
        params[:inquiry_id],
        params[:contact_url],
        params[:status]
      )
    end

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

    @prev_customer = @customers.where("customers.id < ?", @customer.id).last
    @next_customer = @customers.where("customers.id > ?", @customer.id).first
    @contact_tracking = @sender.contact_trackings.where(customer: @customer).order(created_at: :desc).first

    contactor = Contactor.new(@inquiry, @sender)

    @contact_url = @customer.get_search_url

    @callback_code = @sender.generate_code

    gon.typings = contactor.try_typings(@contact_url, @customer.id)
  end

  def callback
    Rails.logger.info( "inside callback : ")
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

  def okurite_new_status(customers_code, status)
    Rails.logger.info( "@sender : " + status + 'に設定')
    @customer = Customer.where(customers_code: customers_code)
    @customer.update(status: status)
  end

  def bombom(worker_id,inquiry_id,company_name,date,contact_url,customers_code,reserve_code,generation_code)
    uri = URI('http://localhost:6500/api/v1/rocketbumb')
    begin
      Rails.logger.info('登録を開始')
      Rails.logger.info(date.strftime('%Y-%m-%d %H:%M:%S'))
      params = { worker_id:worker_id,inquiry_id:inquiry_id,company_name:company_name,date:date.strftime('%Y-%m-%d %H:%M:%S'),contact_url:contact_url,customers_code:customers_code,reserve_code:reserve_code,generation_code: generation_code}
      res = Net::HTTP.post(uri,params.to_json,'Content-Type' => 'application/json')
      status = res.code.to_i
      Rails.logger.info('ステータス⇨' + "#{status}")
      case status
      when 200 then
        Rails.logger.info('@bot ' + '自動送信を登録しました。')
        return 200
      when 500 then
        Rails.logger.info('@bot 自動送信登録不可 Error')
        return 500
      else
        return 500
      end
    rescue => e
      Rails.logger.info('@bot ' + e.to_s)
      return 500
    end
  end

  def urlhanter(url)
    if url.include? == "求人ボックス" or url.include? == "indeed.com"
      return 500
    end
    return 200
  end


  def autosettings
    #Rails.logger.info( "date : " + DateTime.parse(params[:date]).to_yaml)
    Rails.logger.info( "count : " + params[:count].to_s)
    @q = Customer.ransack(params[:q])
    @customers = @q.result.distinct
    save_cont = 0
    err_cont = 0
    continue_cont = 0
    @rancode = SecureRandom.alphanumeric(15)
    @sender = Sender.find(params[:sender_id])
     Rails.logger.info( "@sender : " + @sender.attributes.inspect)
    @customers.each do |cust|
      unless ((params[:count]).to_i < (save_cont+1))
        @generation_code = SecureRandom.alphanumeric(15)
        @inquiry_id = @sender.default_inquiry_id
        @url = cust.get_search_url
        @bom = self.bombom(
              current_worker&.id,
              @inquiry_id,
              cust.company,
              DateTime.parse(params[:date]),
              @url,
              cust.customers_code,
              @rancode,
              @generation_code
        )
        Rails.logger.info( "@bom : " + "#{@bom}")
        if @bom.to_i == 200
          @sender.auto_send_contact!(
            @sender.generate_code,
            cust.id,
            current_worker&.id,
            @inquiry_id,
            DateTime.parse(params[:date]),
            @url,
            "自動送信予定",
            cust.customers_code,
            @rancode,
            @generation_code
          )
          continue_cont += 1
        elsif @bom.to_i == 500
          Rails.logger.info( "@bot : " + "データエラー")
          @sender.auto_send_contact!(
            @sender.generate_code,
            cust.id,
            current_worker&.id,
            @inquiry_id,
            DateTime.parse(params[:date]),
            cust.get_search_url,
            "送信不可",
            cust.customers_code,
            @rancode,
            @generation_code
          )
          err_cont += 1
        end
        save_cont += 1
      end
    end
      Rails.logger.info( "save_cont: " + save_cont.to_s)
    redirect_to sender_okurite_index_path(id:@sender.id,q: params[:q]&.permit!, page: params[:page]), notice:"#{continue_cont}件登録成功しました。登録エラー#{err_cont}件"
  end

  def bulk_delete
    sender = Sender.find(params[:sender_id])
    target = sender.contact_trackings.where(status: %w[自動送信不可 送信不可])
    target.destroy_all
    flash[:notice] = "一括削除に成功しました"
    redirect_to sender_okurite_index_path(sender.id)
  rescue
    flash[:alert] = "一括削除に失敗しました"
    redirect_to sender_okurite_index_path(sender.id)
  end

  private

  def set_sender
    @sender = Sender.find(params[:sender_id])
  end



  def set_customers
    @q = Customer.ransack(params[:q])
    @customers = @q.result
    #@customers = @customers.last_contact_trackings_only(@sender.id)
    Rails.logger.info(params[:q])
    if params[:statuses]&.map(&:presence)&.compact.present?
      @customers = @customers.eager_load(:contact_trackings).where(contact_trackings: { status: params[:statuses], sender_id: @sender.id })
    end
    if params[:contact_tracking_sended_at_lteq]&.map(&:presence)&.compact.present?
      @customers = @customers.before_sended_at(params[:contact_tracking_sended_at_lteq])
    end
  end

  def authenticate_worker_or_admin!
    unless worker_signed_in? || admin_signed_in?
       redirect_to new_worker_session_path, alert: 'error'
    end
  end
end
