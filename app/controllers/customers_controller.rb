require 'rubygems'
class CustomersController < ApplicationController
  before_action :authenticate_admin!, only: [:destroy, :destroy_all, :anayltics, :import, :call_import, :sfa, :mail, :call_history]
  before_action :authenticate_worker!, only: [:extraction,:direct_mail_send]
  # before_action :authenticate_user!, only: [:index]
  before_action :authenticate_worker_or_user, only: [:new, :edit]
  before_action :authenticate_user_or_admin, only: [:index, :show]
  #before_action :authenticate_worker_or_admin, only: [:extraction]
  before_action :set_customers, only: [:update_all_status]
  protect_from_forgery with: :exception, prepend: true
  
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
    #@total_special_number = @customers.map(&:special_number_for_index).sum
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

  def search
    branch = params[:branch]
    address = params[:address]
    @customers = Customer.where(branch: branch, address: address)
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
    
    if params[:commit] == '対象外リストとして登録'
      @customer.skip_validation = true
      @customer.status = "hidden"
    end
  
    if @customer.update(customer_params)
      if worker_signed_in?
        redirect_to draft_path
      else
        redirect_to customer_path(id: @customer.id, q: params[:q]&.permit!, last_call: params[:last_call]&.permit!)
      end
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


  def analytics
    @users = User.all
    # call_count（永久NGとuser.id == 1を除外）
    @call_day = Call.joins(:user).where.not(statu: "永久NG").where.not(users: { id: 1 }).where("calls.created_at >= ? AND calls.created_at <= ?", Time.zone.now.beginning_of_day, Time.zone.now.end_of_day).count
    @call_week = Call.joins(:user).where.not(statu: "永久NG").where.not(users: { id: 1 }).where("calls.created_at >= ? AND calls.created_at <= ?", Time.zone.now.beginning_of_week, Time.zone.now.end_of_week).count
    @call_month = Call.joins(:user).where.not(statu: "永久NG").where.not(users: { id: 1 }).where("calls.created_at >= ? AND calls.created_at <= ?", Time.zone.now.beginning_of_month, Time.zone.now.end_of_month).count
    # call_app（同様に永久NGとuser.id == 1を除外）
    @call_app_day = Call.joins(:user).where.not(statu: "永久NG").where.not(users: { id: 1 }).where("calls.created_at >= ? AND calls.created_at <= ? AND statu = ?", Time.zone.now.beginning_of_day, Time.zone.now.end_of_day, "APP").count
    @call_app_week = Call.joins(:user).where.not(statu: "永久NG").where.not(users: { id: 1 }).where("calls.created_at >= ? AND calls.created_at <= ? AND statu = ?", Time.zone.now.beginning_of_week, Time.zone.now.end_of_week, "APP").count
    @call_app_month = Call.joins(:user).where.not(statu: "永久NG").where.not(users: { id: 1 }).where("calls.created_at >= ? AND calls.created_at <= ? AND statu = ?", Time.zone.now.beginning_of_month, Time.zone.now.end_of_month, "APP").count
    # APP percentage（同様に永久NGとuser.id == 1を除外）
    @app_day_percentage = @call_day.zero? ? 0 : (@call_app_day.to_f / @call_day.to_f) * 100
    @app_week_percentage = @call_week.zero? ? 0 : (@call_app_week.to_f / @call_week.to_f) * 100
    @app_month_percentage = @call_month.zero? ? 0 : (@call_app_month.to_i / @call_month.to_i) * 100

    @customers = Customer.joins(calls: :contract)
                         .where(calls: { statu: '契約' })
                         .where(contracts: { id: Contract.select(:id) })
                         .where(contracts: { search_1: Customer.select(:industry) })
                         .distinct
                         .select(:industry)
                      
    #@industries_data = INDUSTRY_ADDITIONAL_DATA.keys.map do |industry_name|
     # Customer.analytics_for(industry_name)
    #end
    #@total_revenue = @industries_data.sum { |data| data[:unit_price_inc_tax] * data[:appointment_count] }
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
      @call_today_basic = @calls.where(statu: ["着信留守", "担当者不在","フロントNG","見込","APP","NG","クロージングNG"]).where('created_at > ?', Time.current.beginning_of_day).where('created_at < ?', Time.current.end_of_day).to_a
      @call_count_today = @call_today_basic.count
      @protect_count_today = @call_today_basic.select { |call| call.statu == "見込" }.count
      @protect_convertion_today = (@protect_count_today.to_f / @call_count_today.to_f) * 100
      @app_count_today = @call_today_basic.select { |call| call.statu == "APP" }.count
      @app_convertion_today = (@app_count_today.to_f / @call_count_today.to_f) * 100

      #week
      @call_week_basic = @calls.where(statu: ["着信留守", "担当者不在","フロントNG","見込","APP","NG","クロージングNG"]).where('created_at > ?', Time.current.beginning_of_week).where('created_at < ?', Time.current.end_of_week).to_a
      @call_count_week = @call_week_basic.count
      @protect_count_week = @call_week_basic.select { |call| call.statu == "見込" }.count
      @protect_convertion_week = (@protect_count_week.to_f / @call_count_week.to_f) * 100
      @app_count_week = @call_week_basic.select { |call| call.statu == "APP" }.count
      @app_convertion_week = (@app_count_week.to_f / @call_count_week.to_f) * 100

      #month
      @call_month_basic = @calls.where(statu: ["着信留守", "担当者不在","フロントNG","見込","APP","NG","クロージングNG"]).where('created_at > ?', Time.current.beginning_of_month).where('created_at < ?', Time.current.end_of_month).to_a
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

      @app_customers_last_month = Call.joins(:customer).where('calls.created_at >= ? AND calls.created_at < ?', Time.current.prev_month.beginning_of_month, Time.current.beginning_of_month).select('customers.id')
      @app_customers_last_month_total_industry_value = @app_customers_last_month.present? ? @app_customers_last_month.sum(:industry_code) : 0

      @app_customers = Call.joins(:customer).where('calls.created_at > ?', Time.current.beginning_of_month).where('calls.created_at < ?', Time.current.end_of_month).select('customers.id')
      @app_customers_total_industry_value = @app_customers.present? ? @app_customers.sum(:industry_code) : 0

      @industry_mapping = Customer::INDUSTRY_MAPPING
      @app_calls_counts = calculate_app_calls_counts
    when "workers" then
      @customers_app = @customers.where(call_id: 1)
      #today
      @call_today_basic = @calls.where('created_at > ?', Time.current.beginning_of_day).where('created_at < ?', Time.current.end_of_day).where.not(statu:"永久NG").to_a
      @call_count_today = @call_today_basic.count
      @protect_count_today = @call_today_basic.select { |call| call.statu == "見込" }.count
      @protect_convertion_today = (@protect_count_today.to_f / @call_count_today.to_f) * 100
      @app_count_today = @call_today_basic.select { |call| call.statu == "APP" }.count
      @app_convertion_today = (@app_count_today.to_f / @call_count_today.to_f) * 100

      #week
      @call_week_basic = @calls.where('created_at > ?', Time.current.beginning_of_week).where('created_at < ?', Time.current.end_of_week).where.not(statu:"永久NG").to_a
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

  def copy
    @customer = Customer.find(params[:id])
    @user = current_user
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

 def print
    report = Thinreports::Report.new layout: "app/reports/layouts/invoice.tlf"
    
    @industries_data.each do |data|
      create_pdf_page(report, data)
    end

    send_data(report.generate, filename: "industries_report_#{Time.zone.now.to_formatted_s(:number)}.pdf", type: "application/pdf")
  end

  def generate_pdf
    industry_name = params[:industry_name]
    data = INDUSTRY_ADDITIONAL_DATA[industry_name]

    if data.nil?
      redirect_to some_path, alert: "#{industry_name}のデータが見つかりません。"
      return
    end

    report = Thinreports::Report.new layout: 'app/reports/layouts/invoice.tlf'
    create_pdf_page(report, data)

    send_data report.generate, filename: "#{industry_name}.pdf", type: 'application/pdf', disposition: 'attachment'
  end

  def send_email
    @customer = Customer.find(params[:id])
    @user = current_user
  end

  def send_email_send
    @customer = Customer.find(params[:id])
    @user = current_user
    Rails.logger.debug(params.inspect)  # パラメータをログに出力
  
    email_params = params.require(:mail).permit(:company, :first_name, :mail, :body, :company_name, :user_name)
    CustomerMailer.teleapo_send_email(@customer, email_params).deliver_now
    redirect_to customers_path(@customer), notice: 'Email sent successfully!'
  end
  

  def extraction
    @q = Customer.ransack(params[:q])
    @customers = @q.result
    @customers = @customers.order("created_at DESC").where(extraction_count: nil).where(tel: nil).page(params[:page]).per(20)
    #電話番号nilから作業ステータスがないものの一覧へ変更する
    #@customers = @customers.order("created_at DESC").where("created_at > ?", Time.current.beginning_of_day).where("created_at < ?", (Time.current.beginning_of_day + 6.day).at_end_of_day).page(params[:page]).per(20)
  end

  def calculate
    user = User.find(params[:user_id])
    input_val = params[:input_val].to_i
    user_calls_count = user.calls.where('created_at > ?', Time.current.beginning_of_month).where('created_at < ?', Time.current.end_of_month).count
  
    answer = user_calls_count / input_val.to_f
    answer = answer.nan? ? 0 : answer
  
    render json: { answer: answer.round(2) }
  end

  def draft
    if admin_signed_in?
      @q = Customer.where(status:"draft").where.not(tel: nil).ransack(params[:q])
      @customers = @q.result.page(params[:page]).per(100)
    else
      @q = Customer.where(status:"draft").where(tel: nil).ransack(params[:q])
      @customers = @q.result.page(params[:page]).per(100)
    end
     
  end
  
  def update_all_status
    checked_data = params[:updates].keys
    checked_data.each do |id|
      customer = Customer.find(id)
      customer.update(status: :published)
    end
    redirect_to draft_path
  end

  private
  def set_customers
    @customers = Customer.where(id: params[:updates].keys)
  end

  def display_customer_names
    customer_info = []
    INDUSTRY_MAPPING.each do |customer_name, info|
      customer_info << "#{customer_name}: #{info[:company_name]}"
    end
    customer_info
  end

  def create_pdf_page(report, data)
    report.start_new_page do |page|

      industry_name = data[:name]
      start_of_month = Time.current.beginning_of_month
      end_of_month = Time.current.end_of_month
  
      appointment_count = Call.joins(:customer)
                              .where("customers.industry LIKE ? AND calls.created_at >= ? AND calls.created_at <= ?", "%#{industry_name}%", start_of_month, end_of_month)
                              .where(calls: { statu: "APP" })
                              .count
      # 現在の日時を取得し、指定の形式にフォーマット
      current_time = Time.now.strftime('%Y年%m月%d日')  
      # 合計値の計算
      unit_price_ex_tax = data[:unit_price_ex_tax] || 0
      appointment_count = data[:appointment_count] || 0
      total = unit_price_ex_tax * appointment_count
      # 税金の計算（合計値の10%とする）
      tax = total * 0.10
      # 税込み合計値の計算
      all = total + tax
      # 支払い月の計算（翌月の年月 + data[:closing_date]）
      next_month = Time.now.next_month.strftime('%Y年%m月')
      payment_month = "#{next_month}#{data[:closing_date]}"
  
      page.values(
        company: data[:name], # 会社名
        created_at: current_time, # 発行日
        text: data[:appointment_count], # アポカウント
        unit_price_ex_tax: data[:unit_price_ex_tax], # 単価
        tax: tax, # 税金
        tax2: tax, # 税金
        all: all, # 税込み合計
        all_1: all, # 税込み合計
        payment: payment_month, # 支払い月
        #total: total, # 合計
        total_1: total, # 合計
        text_2: total, # 合計
      )
    end
  end

  def calculate_app_calls_counts
    counts = {}
    @industry_mapping.each do |key, value|
      calls = Customer.joins(:calls).where(industry: value[:industry], calls: { statu: 'APP' }).count
      puts "Key: #{key}, Value: #{value}, Calls Count: #{calls}"
      counts[key] = calls
    end
    counts
  end

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
        :forever
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
