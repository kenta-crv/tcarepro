require 'rubygems'
class CustomersController < ApplicationController
  before_action :authenticate_admin!, only: [:destroy, :destroy_all, :analytics, :import, :call_import, :sfa, :mail, :call_history]
  #before_action :authenticate_worker!, only: [:extraction, :direct_mail_send]
  before_action :authenticate_worker_or_user, only: [:new, :edit, :create, :update]
  before_action :authenticate_user_or_admin, only: [:index, :show]
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
  
    # 3コール以内プログラム
    if params[:search] && params[:search][:ltec_calls_count].present?
      @customers = @customers.ltec_calls_count(params[:search][:ltec_calls_count].to_i)
    end
  
    # 最後の呼び出しの条件に一致する顧客をフィルタリング
    @customers = @customers.where(id: last_call) if last_call
  
    # 電話番号が存在する顧客のみをフィルタリング
    @customers = @customers.where.not(tel: [nil, ""])
  
    @csv_customers = @customers.distinct.preload(:calls)
    @customers = @customers.distinct.preload(:calls).page(params[:page]).per(100) #エクスポート総数
  
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
    if worker_signed_in?
      # 電話番号がない顧客のみを表示
      @q = Customer.where(status: "draft").where("TRIM(tel) = ''")
      # 他の人が既に作業を完了していない顧客をフィルター
      @q = @q.where.not(id: Call.select(:customer_id))
      # 管理者を除外
      if current_user && current_user.admin?
        @q = @q.where.not(user_id: User.admins.pluck(:id))
      end
      @customers = @q.ransack(params[:q]).result.page(params[:page]).per(100)
    end
  end

  def update
    @customer = Customer.find(params[:id])
    if params[:commit] == '対象外リストとして登録'
      @customer.skip_validation = true
      @customer.status = "hidden"
    end
    
    # @next_draft を次の編集対象顧客として定義
    @next_draft = Customer.where(status: 'draft').where('id > ?', @customer.id).order(:id).first
  
    if @customer.update(customer_params)
      if worker_signed_in?
        if @next_draft
          redirect_to edit_customer_path(
            id: @next_draft.id,
            industry_name: params[:industry_name]
          )
        else
          redirect_to request.referer, notice: 'リストが終了しました。リスト追加を行いますので、管理者に連絡してください。'
        end
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

  def information
    @calls = Call.all
    @customers =  Customer.all
    @admins = Admin.all
    @users = User.all
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

      @industries_data = INDUSTRY_ADDITIONAL_DATA.keys.map do |industry_name|
        Customer.analytics_for(industry_name)
      end
  end

  def news
    @customers =  Customer.all
  end

  #def copy
   # @customer = Customer.find(params[:id])
    #@user = current_user
  #end

  def import
    if params[:file].present?
      result = Customer.combined_import(params[:file])

      notice_message = "#{result[:total_imported]}件新規インポート、" \
                       "#{result[:new_import_count]}件新規再投稿、" \
                       "#{result[:repost_count]}件再掲載、" \
                       "#{result[:draft_count]}件ドラフト登録が行われました。"
      
      redirect_to customers_url, notice: notice_message
    else
      redirect_to customers_url, alert: "ファイルが選択されていません。"
    end
  end

  def print
    report = Thinreports::Report.new layout: "app/reports/layouts/invoice.tlf"
    @industries_data ||= INDUSTRY_ADDITIONAL_DATA.keys.map do |data|
      Customer.analytics_for(data)
    end
    
    @industries_data.each do |data|
      create_pdf_page(report, data)
    end
    
    send_data(report.generate, filename: "industries_report_#{Time.zone.now.to_formatted_s(:number)}.pdf", type: "application/pdf")
  end

  def generate_pdf
    industry_name = params[:industry_name]
    
    # `@industries_data` からデータを取得するために、情報が必要です。
    @industries_data ||= INDUSTRY_ADDITIONAL_DATA.keys.map do |name|
      Customer.analytics_for(name)
    end
    
    # `@industries_data` を利用して、`data` を設定します
    data = @industries_data.find { |d| d[:industry_name] == industry_name }
    
    if data.nil?
      Rails.logger.error("No data found for industry name: #{industry_name}")
      return
    end
    
    report = Thinreports::Report.new layout: 'app/reports/layouts/invoice.tlf'
    create_pdf_page(report, data)
    
    send_data report.generate, filename: "#{industry_name}.pdf", type: 'application/pdf', disposition: 'attachment'
  end

  def thinreports_email
    industry_name = params[:industry_name]

    # `@industries_data`から該当するデータを取得
    @industries_data ||= INDUSTRY_ADDITIONAL_DATA.keys.map do |name|
      Customer.analytics_for(name)
    end

    data = @industries_data.find { |d| d[:industry_name] == industry_name }

    if data.nil?
      Rails.logger.error("No data found for industry name: #{industry_name}")
      redirect_to customers_path, alert: "指定された業界のデータが見つかりませんでした。"
      return
    end

    # PDFを生成
    report = Thinreports::Report.new layout: 'app/reports/layouts/invoice.tlf'
    create_pdf_page(report, data)
    pdf_content = report.generate

    # メールを送信
    CustomerMailer.send_thinreports_data(data, pdf_content).deliver_now

    redirect_to customers_path, notice: "メールが送信されました"
  end
  
  def send_email
    @customer = Customer.find(params[:id])
    @user = current_user
  end

  def send_email_send
    @customer = Customer.find(params[:id])
    @user = current_user  
    email_params = params.require(:mail).permit(:company, :first_name, :mail, :body, :company_name, :user_name)
    CustomerMailer.teleapo_send_email(@customer, email_params).deliver_now
    redirect_to customers_path, notice: 'Email sent successfully!'
  end
  

  def extraction
    @q = Customer.ransack(params[:q])
    @customers = @q.result
    @customers = @customers.order("created_at DESC").where(extraction_count: nil).where(tel: nil).page(params[:page]).per(20)
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
    @industries = Customer::INDUSTRY_MAPPING.keys
    if admin_signed_in?
      @q = Customer.where(status: "draft").where.not("TRIM(tel) = ''").ransack(params[:q])
      @customers = @q.result.page(params[:page]).per(100)
    else
      @q = Customer.where(status: "draft").where("TRIM(tel) = ''").ransack(params[:q])
      @customers = @q.result.page(params[:page]).per(100)
    end
  end

  def filter_by_industry
    industry_name = params[:industry_name]
    @industries = Customer::INDUSTRY_MAPPING.keys
    if admin_signed_in?
      @q = Customer.where(status: "draft").where.not("TRIM(tel) = ''").where(industry: industry_name).ransack(params[:q])
    else
      @q = Customer.where(status: "draft").where("TRIM(tel) = ''").where(industry: industry_name).ransack(params[:q])
    end
    @customers = @q.result.page(params[:page]).per(100)
    render :draft
  end
  
  def update_all_status
    status = params[:status] || 'hidden'
    published_count = 0
    hidden_count = 0
    @customers.each do |customer|
      customer.skip_validation = true
      if status == 'hidden'
        if customer.update(status: 'hidden')
          hidden_count += 1
        end
      else
        if customer.update(status: nil)
          published_count += 1
        end
      end
    end
    flash[:notice] = "#{published_count}件が公開され、#{hidden_count}件が非表示にされました。"
    redirect_to customers_path
  end

  private

  def set_customers
    customer_ids = params[:deletes]&.keys
    if customer_ids.present?
      @customers = Customer.where(id: customer_ids)
    else
      @customers = Customer.none
    end
  end

  def display_customer_names
    customer_info = []
    INDUSTRY_MAPPING.each do |customer_name, info|
      customer_info << "#{customer_name}: #{info[:company_name]}"
    end
    customer_info
  end

  def create_pdf_page(report, data)
    customer = @customer
    report.start_new_page do |page|

      company_name = data[:company_name]
      start_of_month = Time.current.beginning_of_month
      end_of_month = Time.current.end_of_month
      app_count = data[:app_count]
      # 現在の日時を取得し、指定の形式にフォーマット
      current_time = Time.now.strftime('%Y年%m月%d日')  
      # 合計値の計算
      industry_code = data[:industry_code]
      total = (data[:industry_code] * data[:app_count])
      # 税金の計算（合計値の10%とする）
      tax = (total * 0.10).to_i
      # 税込み合計値の計算
      all = (total + tax).to_i
      formatted_all = all.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1,')
      # 支払い月の計算（翌月の年月
      next_month = Time.now.next_month.strftime('%Y年%m月')
      payment_month = "#{next_month}#{data[:payment_date]}"
  
      page.values(
        company_name: company_name, # 会社名
        created_at: current_time, # 発行日
        app_count: app_count, # アポカウント
        industry_code: industry_code, # 単価
        total: total, # 税抜合計
        total_1: total, # 税抜合計
        total_2: total, # 税抜合計
        all: formatted_all, # 税込み合計
        all_1: all, # 税込み合計
        tax_price: tax, # 税抜合計
        payment: payment_month, # 支払い月        
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
        :forever,
        :industry_code,
        :company_name,
        :payment_date,
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
      unless user_signed_in? || worker_signed_in?
        redirect_to new_worker_session_path, alert: 'error'
      end
    end
end