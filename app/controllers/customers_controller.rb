require 'rubygems'
class CustomersController < ApplicationController
  before_action :authenticate_admin!, only: [:destroy, :destroy_all, :sfa, :mail, :call_history]
  #before_action :authenticate_worker!, only: [:extraction, :direct_mail_send]
  before_action :authenticate_worker_or_user, only: [:new, :edit, :create, :update]
  before_action :authenticate_user_or_admin, only: [:index, :show]
  before_action :set_customers, only: [:update_all_status]
  protect_from_forgery with: :exception, prepend: true
  
  def index
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
  
    # 電話番号が存在し、かつstatusがnilの顧客のみをフィルタリング
    @customers = @customers.where.not(tel: [nil, "", " "]).where(status: nil)
  
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
    @customers = @q.result.includes(:last_call)
    @customers = @customers.where( id: last_call )  if last_call
    @customers = @customers.where.not(tel: [nil, "", " "])
    #@customers = @customers.where(status: [nil, "", " "])
    @prev_customer = @customers.where("customers.id < ?", @customer.id).last
    @next_customer = @customers.where("customers.id > ?", @customer.id).first
    @call = Call.new
    @is_auto_call = (params[:is_auto_call] == 'true')
    @user = current_user
    @worker = current_worker
    #@sender = current_sender ?  current_sender : Sender.new
  end

  def new
    @customer = Customer.new
  end

  def easy 
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
      ## 他の人が既に作業を完了していない顧客をフィルター
      #@q = @q.where.not(id: Call.select(:customer_id))
      # 管理者を除外
      #if current_user && current_admin?
      #  @q = @q.where.not(user_id: User.admins.pluck(:id))
      #end
      @customers = @q.ransack(params[:q]).result.page(params[:page]).per(100)
    end
  end

  def update
    @customer = Customer.find(params[:id])
  
    if params[:commit] == '対象外リストとして登録'
      @customer.skip_validation = true
      @customer.status = "hidden"
      @customer.save(validate: false)
    end
  
  # admin または user がサインインしている場合、バリデーションをスキップ
  if admin_signed_in? || user_signed_in?
    @customer.skip_validation = true
  end

  
    # 現在のフィルタ条件を考慮して次のdraft顧客を取得
    @q = Customer.where(status: 'draft').where('id > ?', @customer.id)
  
    if params[:industry_name].present?
      @q = @q.where(industry: params[:industry_name])
    end
  
    if params[:tel_filter] == "with_tel"
      @q = @q.where.not("TRIM(tel) = ''")
    elsif params[:tel_filter] == "without_tel"
      @q = @q.where("TRIM(tel) = ''")
    end
  
    @next_draft = @q.order(:id).first
  
    if @customer.update(customer_params)
      if worker_signed_in?
        if @next_draft
          redirect_to edit_customer_path(
            id: @next_draft.id,
            industry_name: params[:industry_name],
            tel_filter: params[:tel_filter]
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
    checked_data = params[:deletes].keys # チェックされたデータを取得
    deleted_count = Customer.where(id: checked_data).destroy_all # 削除処理を実行
    if deleted_count.present?
      redirect_to customers_path, notice: "draftから#{deleted_count.size}件削除しました。" # 削除件数を含めたメッセージ
    else
      redirect_to customers_path, alert: '削除に失敗しました。'
    end
  end

  def information
    @calls = Call.joins(:customer)
    @customers =  Customer.all
    @admins = Admin.all
    @users = User.all
    @customers_app = @customers.where(call_id: 1)
      #today
      @call_today_basic = @calls.where(statu: ["着信留守", "担当者不在","フロントNG","見込","APP","NG","クロージングNG","受付NG","自己紹介NG","質問段階NG","日程調整NG"])
                          .where('calls.created_at > ?', Time.current.beginning_of_day)
                          .where('calls.created_at < ?', Time.current.end_of_day)
                          .to_a
      @call_count_today = @call_today_basic.count
      @protect_count_today = @call_today_basic.select { |call| call.statu == "見込" }.count
      @protect_convertion_today = (@protect_count_today.to_f / @call_count_today.to_f) * 100
      @app_count_today = @call_today_basic.select { |call| call.statu == "APP" }.count
      @app_convertion_today = (@app_count_today.to_f / @call_count_today.to_f) * 100

      #week
      @call_week_basic = @calls.where(statu: ["着信留守", "担当者不在","フロントNG","見込","APP","NG","クロージングNG","受付NG","自己紹介NG","質問段階NG","日程調整NG"])
      .where('calls.created_at > ?', Time.current.beginning_of_week)
      .where('calls.created_at < ?', Time.current.end_of_week)
      .to_a
      @call_count_week = @call_week_basic.count
      @protect_count_week = @call_week_basic.select { |call| call.statu == "見込" }.count
      @protect_convertion_week = (@protect_count_week.to_f / @call_count_week.to_f) * 100
      @app_count_week = @call_week_basic.select { |call| call.statu == "APP" }.count
      @app_convertion_week = (@app_count_week.to_f / @call_count_week.to_f) * 100

      #month
      @call_month_basic = @calls.where(statu: ["着信留守", "担当者不在","フロントNG","見込","APP","NG","クロージングNG","受付NG","自己紹介NG","質問段階NG","日程調整NG"])
      .where('calls.created_at > ?', Time.current.beginning_of_month)
      .where('calls.created_at < ?', Time.current.end_of_month)
      .to_a
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

      @companies_data = INDUSTRY_ADDITIONAL_DATA.keys.map do |company_name|
        Customer.analytics2_for(company_name)
      end.group_by { |data| data[:company_name] }
         .map do |company_name, records|
           # 同じcompany_nameが存在する場合、そのデータをまとめる
           first_record = records.first
      
           # もし必要であれば、複数の同じcompany_nameのデータを合算
           combined_data = {
             company_name: first_record[:company_name],
             industry_code: first_record[:industry_code],
             industry_name: first_record[:industry_name],
             list_count: records.sum { |record| record[:list_count] || 0 },
             call_count: records.sum { |record| record[:call_count] || 0 },
             app_count: records.sum { |record| record[:app_count] || 0 },
             payment_date: first_record[:payment_date] # 日付は一番最初のデータを使用
           }
           combined_data
         end
  end

  def news
    @customers =  Customer.all
  end

  #def all_import
   # skip_repurpose = params[:skip_repurpose]
  
    # Save uploaded file temporarily
  #  uploaded_file = params[:file]
  #  temp_file_path = Rails.root.join('tmp', "#{SecureRandom.uuid}_#{uploaded_file.original_filename}")
  #  File.open(temp_file_path, 'wb') do |file|
  #    file.write(uploaded_file.read)
  #  end
  
    # Enqueue background job
  #  skip_repurpose_flag = params[:skip_repurpose] == "1"
   # CustomerImportJob.perform_later(temp_file_path.to_s,{ 'skip_repurpose' => skip_repurpose_flag } )
  
   # redirect_to customers_url, notice: 'インポート処理をバックグラウンドで実行しています。完了までしばらくお待ちください。'
  #end

  def all_import
    uploaded_file = params[:file]
  
    temp_file_path = Rails.root.join('tmp', "#{SecureRandom.uuid}_#{uploaded_file.original_filename}")
    File.open(temp_file_path, 'wb') do |file|
      file.write(uploaded_file.read)
    end
  
    CustomerImportJob.perform_later(temp_file_path.to_s)
  
    redirect_to customers_url, notice: 'インポート処理をバックグラウンドで実行しています。完了までしばらくお待ちください。'
  end

  def print
    report = Thinreports::Report.new layout: "app/reports/layouts/invoice.tlf"
    
    @companies_data = INDUSTRY_ADDITIONAL_DATA.keys.map do |company_name|
      Customer.analytics2_for(company_name)
    end.group_by { |data| data[:company_name] }
    .map do |company_name, records|
      first_record = records.first
      combined_data = {
        company_name: first_record[:company_name],
        industry_code: first_record[:industry_code],
        industry_name: first_record[:industry_name],
        list_count: records.sum { |record| record[:list_count] || 0 },
        call_count: records.sum { |record| record[:call_count] || 0 },
        app_count: records.sum { |record| record[:app_count] || 0 },
        payment_date: first_record[:payment_date]
      }
      combined_data
    end  
    @companies_data.each do |data|
      create_pdf_page(report, data)
    end
    send_data(report.generate, filename: "industries_report_#{Time.zone.now.to_formatted_s(:number)}.pdf", type: "application/pdf")
  end
  
  def generate_pdf
    company_name = params[:company_name]
    @companies_data ||= INDUSTRY_ADDITIONAL_DATA.keys.map do |name|
      Customer.analytics2_for(name)
    end.group_by { |data| data[:company_name] }
    .map do |company_name, records|
      first_record = records.first
      combined_data = {
        company_name: first_record[:company_name],
        industry_code: first_record[:industry_code],
        industry_name: first_record[:industry_name],
        list_count: records.sum { |record| record[:list_count] || 0 },
        call_count: records.sum { |record| record[:call_count] || 0 },
        app_count: records.sum { |record| record[:app_count] || 0 },
        payment_date: first_record[:payment_date]
      }
      combined_data
    end
    data = @companies_data.find { |d| d[:company_name] == company_name }
    if data.nil?
      Rails.logger.error("No data found for industry name: #{company_name}")
      return
    end
    report = Thinreports::Report.new layout: 'app/reports/layouts/invoice.tlf'
    create_pdf_page(report, data)
    send_data report.generate, filename: "#{company_name}.pdf", type: 'application/pdf', disposition: 'attachment'
  end
  
  def thinreports_email
    company_name = params[:company_name]
    Rails.logger.info("Looking for customer with company_name: #{company_name}")
  
    # @companies_dataの取得と処理
    @companies_data ||= INDUSTRY_ADDITIONAL_DATA.keys.map do |name|
      Customer.analytics2_for(name)
    end
  
    data = @companies_data.find { |d| d[:company_name] == company_name }
    app_count_customers = data[:app_count_customers]
  
    app_count_customers.each do |customer|
      customer.calls.where(statu: "APP").each do |call|
        puts "Company: #{customer.company}, Call Created At: #{call.created_at}"
      end
    end
    # 顧客情報の取得とindustry_mailの確認
    customer = Customer.where("company_name LIKE ?", "%#{company_name}%").first
    industry_mail = customer.industry_mail
  
    # ThinreportsでPDFを作成
    report = Thinreports::Report.new layout: 'app/reports/layouts/invoice.tlf'
    create_pdf_page(report, data)  # PDF作成メソッドを利用
    pdf_content = report.generate
  
    # メール送信、データも渡す
    CustomerMailer.send_thinreports_data(industry_mail, data, pdf_content).deliver_now  
    redirect_to customers_path, notice: "メールが送信されました"
  end
  
  def jwork
    @customers = Customer
      .where("customers.industry LIKE ?", "%J Work%")
      .joins(:calls)
      .where(calls: { statu: "APP" })
      .distinct
      .includes(:calls)
  end
  
  def send_email
    @customer = Customer.find(params[:id])
    @user = current_user
  
    body = <<~TEXT
      #{@customer.company} #{@customer.first_name}様
  
      お世話になります。私、国内転職外国人紹介プラットフォーム『J Work』の#{@user.user_name}でございます。
  
      この度はお忙しい中、弊社スタッフとお話の機会をいただきありがとうございました。
  
      改めて弊社は国内最大級の外国人転職人材を取り扱っている企業となります。簡単に以下、弊社人材特長を明記しております。
  
      【J Workの人材】
      登録者数：毎月300~500名
      人材層：国内転職外国人材100%
      国内在住：平均2〜10年
      日本語レベル：N1~N4
      ビザの種類：永住ビザ・技術人文国際ビザ・特定技能ビザ
  
      更に当社人材について、県外への転職が可能な人材が全体の【80%前後】を占めており、非常に柔軟な転職が可能となっております。
  
      J Workでは『成果報酬0円』で人数無制限で採用頂くことが可能となっておりますので、この機会に是非ともご利用いただければと存じます。
  
      【サービス資料】
      https://tcare.pro/documents?from=#{@customer.id}
  
      尚、当社では0円採用を実現するためオンライン商談等は行なっておらず、公式LINEのみの対応となっております。
  
      【公式LINE】
      https://lin.ee/l5EzcZW
  
      以上、ご確認よろしくお願い致します。
  
      株式会社セールスプロ
      【0円採用】国内転職外国人紹介プラットフォーム『J Work』
      https://j-work.jp/
      info@j-work.jp
      東京都港区芝5-27-3 MBC・Aー9
    TEXT
  
    email_params = { mail: @customer.mail, body: body }
  
    CustomerMailer.teleapo_send_email(@customer, email_params).deliver_now
    CustomerMailer.teleapo_reply_email(@customer, email_params).deliver_now
  
    redirect_to customers_path, notice: "#{@customer.company}(#{@customer.mail})にメールを送信しました。"
  end
  
  def documents
    customer = Customer.find_by(id: params[:from]) # クエリで顧客IDを受け取る
  
    if customer
      # アクセスログ保存
      AccessLog.create!(
        customer: customer,
        path: request.path,
        ip: request.remote_ip,
        accessed_at: Time.current
      )
  
      # 管理者に通知メール送信
      CustomerMailer.clicked_notice(customer).deliver_later
    end
  
    pdf_path = Rails.root.join('public', 'documents.pdf')
    if File.exist?(pdf_path)
      send_file pdf_path, filename: 'documents.pdf', type: 'application/pdf', disposition: 'attachment'
    else
      render plain: 'ファイルが見つかりません', status: 404
    end
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
    # crowdworkタイトルの初期化
    @crowdworks = Crowdwork.all || []

    # Adminを優先した条件分岐
    @customers = case
    when admin_signed_in? && params[:tel_filter] == "with_tel"
      Customer.where(status: "draft").where.not(tel: [nil, '', ' '])
    when admin_signed_in? && params[:tel_filter] == "without_tel"
      Customer.where(status: "draft").where(tel: [nil, '', ' '])
    when worker_signed_in?
      Customer.where(status: "draft").where(tel: [nil, '', ' '])
    else
      Customer.where(status: "draft").where.not(tel: [nil, '', ' '])
    end

    # タイトルごとの件数を計算
    tel_with_counts = Customer.where(status: "draft").where.not(tel: [nil, '', ' ']).group(:industry).count
    tel_without_counts = Customer.where(status: "draft").where(tel: [nil, '', ' ']).group(:industry).count

    @industry_counts = @crowdworks.each_with_object({}) do |crowdwork, hash|
      hash[crowdwork.title] = {
        tel_with: tel_with_counts[crowdwork.title] || 0,
        tel_without: tel_without_counts[crowdwork.title] || 0
      }
    end

    # ページネーション
    @customers = @customers.page(params[:page]).per(100)
  end

  def filter_by_industry
    # crowdworkタイトルの初期化
    @crowdworks = Crowdwork.all || []

    # タイトルによるフィルタリング
    industry_name = params[:industry_name]
    base_query = Customer.where(status: "draft")
    base_query = base_query.where(industry: industry_name) if industry_name.present?

    # Adminを優先した条件分岐
    @customers = case
    when admin_signed_in? && params[:tel_filter] == "with_tel"
      base_query.where.not(tel: [nil, '', ' '])
    when admin_signed_in? && params[:tel_filter] == "without_tel"
      base_query.where(tel: [nil, '', ' '])
    when worker_signed_in?
      base_query.where(tel: [nil, '', ' '])
    else
      base_query.where.not(tel: [nil, '', ' '])
    end

    # タイトルごとの件数を計算
    tel_with_counts = Customer.where(status: "draft").where.not(tel: [nil, '', ' ']).group(:industry).count
    tel_without_counts = Customer.where(status: "draft").where(tel: [nil, '', ' ']).group(:industry).count

    @industry_counts = @crowdworks.each_with_object({}) do |crowdwork, hash|
      hash[crowdwork.title] = {
        tel_with: tel_with_counts[crowdwork.title] || 0,
        tel_without: tel_without_counts[crowdwork.title] || 0
      }
    end

    # ページネーション
    @customers = @customers.page(params[:page]).per(100)

    render :draft
  end  
  
  def bulk_action
    @customers = Customer.where(id: params[:deletes].keys)
  
    if params[:commit] == '一括更新'
      update_all_status
    elsif params[:commit] == '一括削除'
      destroy_all
    elsif params[:commit] == '一括削除（社名）'
      destroy_all_by_company
    else
      redirect_to customers_path, alert: '無効なアクションです。'
    end
  end
          
  def update_all_status
    status = params[:status] || 'hidden'
    published_count = 0
    hidden_count = 0
    deleted_count = 0
    reposted_count = 0
  
    @customers.each do |customer|
      customer.skip_validation = true
  
      if customer.status == 'draft'
        normalized_company = Customer.normalized_name(customer.company)
        normalized_tel = customer.tel.to_s.delete('-')
  
        existing_customer = Customer.where(industry: customer.industry)
                                    .where.not(id: customer.id)
                                    .find do |c|
          # 電話番号比較（ハイフン無視）
          c_tel = c.tel.to_s.delete('-')
          tel_match = normalized_tel.present? && c_tel.present? && normalized_tel == c_tel
  
          # 会社名比較（法人格除去後、3文字以上一致）
          c_company = Customer.normalized_name(c.company)
          name_match = Customer.name_similarity?(normalized_company, c_company)
  
          tel_match || name_match
        end
  
        if existing_customer
          latest_call = existing_customer.calls.order(created_at: :desc).first
  
          if latest_call && latest_call.created_at <= 2.months.ago
            existing_customer.calls.create(statu: '再掲載')
  
            if customer.worker.present?
              customer.worker.increment!(:deleted_customer_count)
            end
  
            customer.destroy
            reposted_count += 1
            next
          else
            if customer.worker.present?
              customer.worker.increment!(:deleted_customer_count)
            end
  
            customer.destroy
            deleted_count += 1
            next
          end
        end
      end
  
      if status == 'hidden'
        hidden_count += 1 if customer.update_columns(status: 'hidden')
      else
        published_count += 1 if customer.update_columns(status: nil)
      end
    end
  
    flash[:notice] = "#{published_count}件が公開され、#{hidden_count}件が非表示にされ、#{reposted_count}件を再掲載に登録しました。#{deleted_count}件のドラフトが重複のため削除されました。"
    redirect_to customers_path
  end

  def destroy_all_by_company
    all_ids = @customers.flat_map do |customer|
      Customer.where(company: customer.company).pluck(:id)
    end.uniq
  
    customers_to_destroy = Customer.where(id: all_ids)
  
    customers_to_destroy.each do |customer|
      customer.destroy
    end
  
    flash[:notice] = "#{customers_to_destroy.size}件の顧客（同社名を含む）を削除しました。"
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
        :industry_mail,
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