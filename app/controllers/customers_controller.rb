require 'rubygems'
class CustomersController < ApplicationController
  before_action :authenticate_admin!, only: [:destroy, :destroy_all, :anayltics, :import, :call_import, :sfa, :mail, :call_history]
  before_action :authenticate_worker!, only: [:extraction,:direct_mail_send]
  # before_action :authenticate_user!, only: [:index]
  before_action :authenticate_worker_or_user, only: [:new, :edit]
  before_action :authenticate_user_or_admin, only: [:index, :show]
  #before_action :authenticate_worker_or_admin, only: [:extraction]

  def index
    last_call_customer_ids = nil
    Rails.logger.debug("params :" + params.to_s)
    @last_call_params = {}
    if params[:last_call] && !params[:last_call].values.all?(&:blank?)
      @last_call_params = params[:last_call]
      last_call = Call.joins_last_call.select(:customer_id)
      last_call = last_call.where(statu: @last_call_params[:statu]) if !@last_call_params[:statu].blank?
      last_call = last_call.where("calls.time >= ?", @last_call_params[:time_from]) if !@last_call_params[:time_from].blank?
      last_call = last_call.where("calls.time <= ?", @last_call_params[:time_to]) if !@last_call_params[:time_to].blank?
      last_call = last_call.where("calls.created_at >= ?", @last_call_params[:created_at_from]) if !@last_call_params[:created_at_from].blank?
      last_call = last_call.where("calls.created_at <= ?", @last_call_params[:created_at_to]) if !@last_call_params[:created_at_to].blank?
    end
    @q = Customer.ransack(params[:q]) || Customer.ransack(params[:last_call])
    @customers = @q.result || @q.result.includes(:last_call)
  #  3コール以内プログラム
    if params[:search] && params[:search][:ltec_calls_count].present?
     @customers = @customers.ltec_calls_count(params[:search][:ltec_calls_count].to_i)
    end
    @customers = @customers.where( id: last_call ) if last_call
    #これに変えると全抽出
    @csv_customers = @customers.distinct.preload(:calls)
    @customers = @customers.distinct.preload(:calls).page(params[:page]).per(100) #エスクポート総数

    respond_to do |format|
     format.html
     format.csv do
        send_data @csv_customers.generate_csv, filename: "customers-#{Time.zone.now.strftime('%Y%m%d%S')}.csv"
     end
    end
  end

  def show
    last_call_customer_ids = nil
    @last_call_params = {}
    if params[:last_call] && !params[:last_call].values.all?(&:blank?)
      @last_call_params = params[:last_call]
      last_call = Call.joins_last_call.select(:customer_id)
      last_call = last_call.where(statu: @last_call_params[:statu]) if !@last_call_params[:statu].blank?
      last_call = last_call.where("calls.time >= ?", @last_call_params[:time_from]) if !@last_call_params[:time_from].blank?
      last_call = last_call.where("calls.time <= ?", @last_call_params[:time_to]) if !@last_call_params[:time_to].blank?
      last_call = last_call.where("calls.created_at >= ?", @last_call_params[:created_at_from]) if !@last_call_params[:created_at_from].blank?
      last_call = last_call.where("calls.created_at <= ?", @last_call_params[:created_at_to]) if !@last_call_params[:created_at_to].blank?
    end
    @customer = Customer.find(params[:id])
    @q = Customer.ransack(params[:q]) || Customer.ransack(params[:last_call])
    @customers = @q.result || @q.result.includes(:last_call)
    @customers = @customers.where( id: last_call )  if last_call
    @call = Call.new
    @prev_customer = @customers.where("customers.id < ?", @customer.id).last
    @next_customer = @customers.where("customers.id > ?", @customer.id).first
    @is_auto_call = (params[:is_auto_call] == 'true')
    @user = current_user
    @worker = current_worker
    @sender = current_sender ?  current_sender : Sender.new
  end

  def new
    @customer = Customer.new
  end

  def create
    @customer = Customer.new(customer_params)
     if @customer.save
       if worker_signed_in?
         redirect_to extraction_path
       else
         redirect_to customer_path(id: @customer.id, q: params[:q]&.permit!, last_call: params[:last_call]&.permit!)
       end
     else
       render 'new'
     end
  end

  def edit
    @customer = Customer.find(params[:id])
  end

  def update
    @customer = Customer.find(params[:id])
    if @customer.update(customer_params)
      redirect_to customer_path(id: @customer.id, q: params[:q]&.permit!, last_call: params[:last_call]&.permit!)
    else
      render 'edit'
    end
  end

  def destroy
    @customer = Customer.find(params[:id])
    @customer.destroy
    redirect_to customers_path
  end

  def destroy_all
    checked_data = params[:deletes].keys #checkデータを受け取る
    if Customer.destroy(checked_data)
      redirect_to customers_path
    else
      render action: 'index'
    end
  end

  def closing 
    @type = params[:type]
    @calls = Call.all
    @customers =  Customer.all
    @admins = Admin.all
    @users = User.all
    @customers_app = @customers.where(call_id: 1)
    #today
    @call_today_basic = @calls.where('created_at > ?', Time.current.beginning_of_day).where('created_at < ?', Time.current.end_of_day).to_a
    @call_count_today = @call_today_basic.count
    @protect_count_today = @call_today_basic.select { |call| call.statu == "見込" }.count
    @protect_convertion_today = (@protect_count_today.to_f / @call_count_today.to_f) * 100
    @app_count_today = @call_today_basic.select { |call| call.statu == "APP" }.count
    @app_convertion_today = (@app_count_today.to_f / @call_count_today.to_f) * 100

    #week
    @call_week_basic = @calls.where('created_at > ?', Time.current.beginning_of_week).where('created_at < ?', Time.current.end_of_week).to_a
    @call_count_week = @call_week_basic.count
    @protect_count_week = @call_week_basic.select { |call| call.statu == "見込" }.count
    @protect_convertion_week = (@protect_count_week.to_f / @call_count_week.to_f) * 100
    @app_count_week = @call_week_basic.select { |call| call.statu == "APP" }.count
    @app_convertion_week = (@app_count_week.to_f / @call_count_week.to_f) * 100

    #month
    @call_month_basic = @calls.where('created_at > ?', Time.current.beginning_of_month).where('created_at < ?', Time.current.end_of_month).to_a
    @call_count_month = @call_month_basic.count
    @protect_count_month = @call_month_basic.select { |call| call.statu == "見込" }.count
    @protect_convertion_month = (@protect_count_month.to_f / @call_count_month.to_f) * 100
    @app_count_month = @call_month_basic.select { |call| call.statu == "APP" }.count
    @app_convertion_month = (@app_count_month.to_f / @call_count_month.to_f) * 100

    #  ステータス別結果
    @call_count_called = @call_month_basic.select { |call| call.statu == "着信留守" }
    @call_count_absence = @call_month_basic.select { |call| call.statu == "担当者不在" }
    @call_count_prospect = @call_month_basic.select { |call| call.statu == "見込" }
    @call_count_app = @call_month_basic.select { |call| call.statu == "APP" }
    @call_count_cancel = @call_month_basic.select { |call| call.statu == "キャンセル" }
    @call_count_ng = @call_month_basic.select { |call| call.statu == "NG" }

    # 企業別アポ状況
    @customer2_sorairo = Customer2.where("industry LIKE ?", "%SORAIRO%")
    @customer2_takumi = Customer2.where("industry LIKE ?", "%アポ匠%")
    @customer2_omg = Customer2.where("industry LIKE ?", "%OMG%")
    @customer2_kousaido = Customer2.where("industry LIKE ?", "%廣済堂%")
    @detail_sorairo = @customer2_sorairo.calls.where("created_at > ?", Time.current.beginning_of_month).where("created_at < ?", Time.current.end_of_month).to_a if @detail_sorairo.present?
    @detail_takumi = @customer2_takumi.calls.where("created_at > ?", Time.current.beginning_of_month).where("created_at < ?", Time.current.end_of_month).to_a if @detail_takumi.present?
    @detail_omg = @customer2_omg.calls.where("created_at > ?", Time.current.beginning_of_month).where("created_at < ?", Time.current.end_of_month).to_a if @detail_omg.present?
    @detail_kousaido = @customer2_kousaido.calls.where("created_at > ?", Time.current.beginning_of_month).where("created_at < ?", Time.current.end_of_month).to_a if @detail_kousaido.present?

    @admins = Admin.all
    @users = User.all

    @detailcalls = Customer2.joins(:calls).select('calls.id')
    @detailcustomers = Call.joins(:customer).select('customers.id')
  end

  def information
    @type = params[:type]
    @calls = Call.all
    @customers =  Customer.all
    @admins = Admin.all
    @users = User.all
    case @type
    when "analy1" then
      @customers_app = @customers.where(call_id: 1)
      #today
      @call_today_basic = @calls.where('created_at > ?', Time.current.beginning_of_day).where('created_at < ?', Time.current.end_of_day).to_a
      @call_count_today = @call_today_basic.count
      @protect_count_today = @call_today_basic.select { |call| call.statu == "見込" }.count
      @protect_convertion_today = (@protect_count_today.to_f / @call_count_today.to_f) * 100
      @app_count_today = @call_today_basic.select { |call| call.statu == "APP" }.count
      @app_convertion_today = (@app_count_today.to_f / @call_count_today.to_f) * 100

      #week
      @call_week_basic = @calls.where('created_at > ?', Time.current.beginning_of_week).where('created_at < ?', Time.current.end_of_week).to_a
      @call_count_week = @call_week_basic.count
      @protect_count_week = @call_week_basic.select { |call| call.statu == "見込" }.count
      @protect_convertion_week = (@protect_count_week.to_f / @call_count_week.to_f) * 100
      @app_count_week = @call_week_basic.select { |call| call.statu == "APP" }.count
      @app_convertion_week = (@app_count_week.to_f / @call_count_week.to_f) * 100

      #month
      @call_month_basic = @calls.where('created_at > ?', Time.current.beginning_of_month).where('created_at < ?', Time.current.end_of_month).to_a
      @call_count_month = @call_month_basic.count
      @protect_count_month = @call_month_basic.select { |call| call.statu == "見込" }.count
      @protect_convertion_month = (@protect_count_month.to_f / @call_count_month.to_f) * 100
      @app_count_month = @call_month_basic.select { |call| call.statu == "APP" }.count
      @app_convertion_month = (@app_count_month.to_f / @call_count_month.to_f) * 100

      #  ステータス別結果
      @call_count_called = @call_month_basic.select { |call| call.statu == "着信留守" }
      @call_count_absence = @call_month_basic.select { |call| call.statu == "担当者不在" }
      @call_count_prospect = @call_month_basic.select { |call| call.statu == "見込" }
      @call_count_app = @call_month_basic.select { |call| call.statu == "APP" }
      @call_count_cancel = @call_month_basic.select { |call| call.statu == "キャンセル" }
      @call_count_ng = @call_month_basic.select { |call| call.statu == "NG" }

      # 企業別アポ状況
      @customer2_sorairo = Customer2.where("industry LIKE ?", "%SORAIRO%")
      @customer2_takumi = Customer2.where("industry LIKE ?", "%アポ匠%")
      @customer2_omg = Customer2.where("industry LIKE ?", "%OMG%")
      @customer2_kousaido = Customer2.where("industry LIKE ?", "%廣済堂%")
      @detail_sorairo = @customer2_sorairo.calls.where("created_at > ?", Time.current.beginning_of_month).where("created_at < ?", Time.current.end_of_month).to_a if @detail_sorairo.present?
      @detail_takumi = @customer2_takumi.calls.where("created_at > ?", Time.current.beginning_of_month).where("created_at < ?", Time.current.end_of_month).to_a if @detail_takumi.present?
      @detail_omg = @customer2_omg.calls.where("created_at > ?", Time.current.beginning_of_month).where("created_at < ?", Time.current.end_of_month).to_a if @detail_omg.present?
      @detail_kousaido = @customer2_kousaido.calls.where("created_at > ?", Time.current.beginning_of_month).where("created_at < ?", Time.current.end_of_month).to_a if @detail_kousaido.present?

      @admins = Admin.all
      @users = User.all

      @detailcalls = Customer2.joins(:calls).select('calls.id')
      @detailcustomers = Call.joins(:customer).select('customers.id')
    when "call_import"
      call_attributes = ["customer_id" ,"statu", "time", "comment", "created_at","updated_at"]
      generate_call =
        CSV.generate(headers:true) do |csv|
          csv << call_attributes
          Call.all.each do |task|
            csv << call_attributes.map{|attr| task.send(attr)}
          end
        end
      respond_to do |format|
        format.html
        format.csv{ send_data generate_call, filename: "calls-#{Time.zone.now.strftime('%Y%m%d%S')}.csv" }
      end
    when "update_import"
      respond_to do |format|
       format.html
       format.csv{ send_data @customers.generate_csv, filename: "customers-#{Time.zone.now.strftime('%Y%m%d%S')}.csv" }
      end
    when "workers" then
      @customers_app = @customers.where(call_id: 1)
      #today
      @call_today_basic = @calls.where('created_at > ?', Time.current.beginning_of_day).where('created_at < ?', Time.current.end_of_day).to_a
      @call_count_today = @call_today_basic.count
      @protect_count_today = @call_today_basic.select { |call| call.statu == "見込" }.count
      @protect_convertion_today = (@protect_count_today.to_f / @call_count_today.to_f) * 100
      @app_count_today = @call_today_basic.select { |call| call.statu == "APP" }.count
      @app_convertion_today = (@app_count_today.to_f / @call_count_today.to_f) * 100

      #week
      @call_week_basic = @calls.where('created_at > ?', Time.current.beginning_of_week).where('created_at < ?', Time.current.end_of_week).to_a
      @call_count_week = @call_week_basic.count
      @protect_count_week = @call_week_basic.select { |call| call.statu == "見込" }.count
      @protect_convertion_week = (@protect_count_week.to_f / @call_count_week.to_f) * 100
      @app_count_week = @call_week_basic.select { |call| call.statu == "APP" }.count
      @app_convertion_week = (@app_count_week.to_f / @call_count_week.to_f) * 100

      #month
      @call_month_basic = @calls.where('created_at > ?', Time.current.beginning_of_month).where('created_at < ?', Time.current.end_of_month).to_a
      @call_count_month = @call_month_basic.count
      @protect_count_month = @call_month_basic.select { |call| call.statu == "見込" }.count
      @protect_convertion_month = (@protect_count_month.to_f / @call_count_month.to_f) * 100
      @app_count_month = @call_month_basic.select { |call| call.statu == "APP" }.count
      @app_convertion_month = (@app_count_month.to_f / @call_count_month.to_f) * 100

      @workers = Worker.all

      @detailcalls = Customer2.joins(:calls).select('calls.id')
      @detailcustomers = Call.joins(:customer).select('customers.id')
    else
   end
  end

  def news
    @customers =  Customer.all
  end

  def import
    cnt = Customer.import(params[:file])
    redirect_to customers_url, notice:"#{cnt}件登録されました。"
  end

  def update_import
    cnt = Customer.update_import(params[:update_file])
    redirect_to customers_url, notice:"#{cnt}件登録されました。"
  end

  def tcare_import
    cnt = Customer.tcare_import(params[:tcare_file])
    redirect_to extraction_url, notice:"#{cnt}件登録されました。"
  end

  def call_import
    cnt = Call.call_import(params[:call_file])
    redirect_to customers_url, notice:"#{cnt}件登録されました。"
  end

  def list
    @q = Customer.ransack(params[:q])
    @customers = @q.result
    @customers = @customers.preload(:calls).order(created_at: 'desc').page(params[:page]).per(20)
  end

  def extraction
    @q = Customer.ransack(params[:q])
    @customers = @q.result
    @customers = @customers.order("created_at DESC").where(extraction_count: nil).where(tel: nil).page(params[:page]).per(20)
    #電話番号nilから作業ステータスがないものの一覧へ変更する
    #@customers = @customers.order("created_at DESC").where("created_at > ?", Time.current.beginning_of_day).where("created_at < ?", (Time.current.beginning_of_day + 6.day).at_end_of_day).page(params[:page]).per(20)
  end
  
  private
    def customer_params
      params.require(:customer).permit(
        :company, #会社名
        :store, #店舗名  #
        :first_name, #担当者
        :last_name, #名前
        :first_kana, #ミョウジ
        :last_kana, #ナマエ
        :tel, #電話番号1
        :tel2, #電話番号2
        :fax, #FAX番号
        :mobile, #携帯番号
        :industry, #業種
        :mail, #メール
        :url, #URL
        :people, #人数
        :postnumber, #郵便番号
        :address, #住所
        :caption, #資本金
        :status, #ステータス
        :title, #取得タイトル
        :other, #その他
        :url_2, #url2
        :customer_tel,
        :choice,
        :contact_url, #問い合わせフォーム
        :inflow, #流入元
        :business, #業種
        :genre, #事業内容
        :history, #過去アポ利用履歴
        :area, #ターゲットエリア
        :target, #対象者
        :meeting, #商談方法
        :experience, #経験則
        :price, #単価
        :number, #件数
        :start, #開始時期
        :remarks, #備考
        :business, #業種
        :extraction_count,
        :send_count,
        :forever,
        :status
       )&.merge(worker: current_worker)
    end

    def authenticate_user_or_admin
      unless user_signed_in? || admin_signed_in?
         redirect_to new_user_session_path, alert: 'error'
      end
    end

    def authenticate_worker_or_admin
      unless worker_signed_in? || admin_signed_in?
         redirect_to new_worker_session_path, alert: 'error'
      end
    end

    def authenticate_worker_or_user
      unless user_signed_in? ||  worker_signed_in?
         redirect_to new_worker_session_path, alert: 'error'
      end
    end

end
