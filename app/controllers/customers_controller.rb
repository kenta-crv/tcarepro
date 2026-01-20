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

  def search
    branch = params[:branch]
    address = params[:address]
    @customers = Customer.where(branch: branch, address: address)
  end

def create
  @customer = Customer.new(customer_params)

  # worker がログインしている場合のみバリデーションを有効
  if worker_signed_in? && current_worker.present?
    @customer.current_worker_id_for_tracking = current_worker.id
    @customer.skip_validation = false
  else
    # worker 以外はバリデーションをスキップ
    @customer.skip_validation = true
  end

  if @customer.save(context: :web)
    # 保存成功
    if worker_signed_in?
      redirect_to new_customer_path, notice: "顧客を作成しました"
    else
      # admin/user などは一覧へ戻す
      redirect_to customers_path, notice: "顧客を作成しました（バリデーションなし）"
    end
  else
    # 保存失敗（worker の場合はバリデーションエラーが出る）
    flash.now[:alert] = @customer.errors.full_messages.join(", ")
    render :new
  end
end


def edit
  @customer = Customer.find(params[:id])
  if @customer.remarks.blank?
    @customer.remarks = <<~TEXT
      ①まず冒頭で恐れ入りますが、現在も御社は人材は募集している形でお間違いなかったでしょうか？
      →

      ②御社で成功報酬等が無く採用ができるなら、人材の質によっては特定技能外国人材でのすぐ面接まで対応いただくことは可能でしょうか？
      →

      ③もう一点、無料となるとご警戒されてしまうと思うので確認となりますが、『特定技能外国人』自体についての仕組みはご存知でしょうか？
      →

      赤枠内の説明可否
      → 説明済・未説明

      【備考】
    TEXT
  end

  if worker_signed_in?
    @q = Customer.where(status: "draft").where("TRIM(tel) = ''")
    @customers = @q.ransack(params[:q]).result.page(params[:page]).per(100)
  end
end

# app/controllers/customers_controller.rb

def update
  @customer = Customer.find(params[:id])

  # 🌟 修正ポイント: worker がログインしている場合、初回更新者をセット
  if worker_signed_in? && current_worker.present?
    @customer.assign_first_editor(current_worker)
  end

  if params[:commit] == '対象外リストとして登録'
    @customer.skip_validation = true
    @customer.status = "hidden"
    @customer.save(validate: false)

  elsif params[:commit] == '公開して一覧へ'
    @customer.status = nil
    @customer.save(validate: false)

    redirect_to customers_path(
      q: params[:q]&.permit!,
      industry_name: params[:industry_name],
      tel_filter: params[:tel_filter]
    ) and return
  end

  # admin または user がサインインしている場合、バリデーションをスキップ
  @customer.skip_validation = true if admin_signed_in? || user_signed_in?

  # 次の draft 顧客を取得（フィルタ考慮）
  @q = Customer.where(status: 'draft').where('id > ?', @customer.id)
  @q = @q.where(industry: params[:industry_name]) if params[:industry_name].present?

  case params[:tel_filter]
  when "with_tel"
    @q = @q.where.not("TRIM(tel) = ''")
  when "without_tel"
    @q = @q.where("TRIM(tel) = ''")
  end

  @next_draft = @q.order(:id).first

  # update 実行
  if @customer.update(customer_params)
    # メール送信
    if params[:commit] == '登録＋J Workメール送信'
      CustomerMailer.teleapo_send_email(@customer, current_user).deliver_now
      CustomerMailer.teleapo_reply_email(@customer, current_user).deliver_now
    elsif params[:commit] == '資料送付'
      CustomerMailer.document_send_email(@customer, current_user).deliver_now
      CustomerMailer.document_reply_email(@customer, current_user).deliver_now
    end

    # worker リダイレクト
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
      redirect_to customer_path(
        id: @customer.id,
        q: params[:q]&.permit!,
        last_call: params[:last_call]&.permit!
      )
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

  def all_import
    uploaded_file = params[:file]
  
    temp_file_path = Rails.root.join('tmp', "#{SecureRandom.uuid}_#{uploaded_file.original_filename}")
    File.open(temp_file_path, 'wb') do |file|
      file.write(uploaded_file.read)
    end
  
    CustomerImportJob.perform_now(temp_file_path.to_s)
  
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
    start_time = Time.current
    # crowdworkタイトルの初期化
    @crowdworks = Crowdwork.all || []

    # 期間パラメータの解釈（未指定可）
    @period_start = nil
    @period_end   = nil
    if params[:period_start].present?
      begin
        @period_start = Date.parse(params[:period_start])
      rescue ArgumentError
        @period_start = nil
      end
    end
    if params[:period_end].present?
      begin
        @period_end = Date.parse(params[:period_end])
      rescue ArgumentError
        @period_end = nil
      end
    end

    # 期間の整合性（逆転していたら入れ替え）
    if @period_start.present? && @period_end.present? && @period_end < @period_start
      @period_start, @period_end = @period_end, @period_start
    end
    range_start = @period_start&.beginning_of_day
    range_end   = @period_end&.end_of_day

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

    # 期間でフィルタ（未指定なら全期間）
    if range_start && range_end
      @customers = @customers.where(created_at: range_start..range_end)
    elsif range_start
      @customers = @customers.where('created_at >= ?', range_start)
    elsif range_end
      @customers = @customers.where('created_at <= ?', range_end)
    end

    # タイトルごとの件数を計算
    tel_with_scope = Customer.where(status: "draft").where.not(tel: [nil, '', ' '])
    tel_without_scope = Customer.where(status: "draft").where(tel: [nil, '', ' '])
    if range_start && range_end
      tel_with_scope = tel_with_scope.where(created_at: range_start..range_end)
      tel_without_scope = tel_without_scope.where(created_at: range_start..range_end)
    elsif range_start
      tel_with_scope = tel_with_scope.where('created_at >= ?', range_start)
      tel_without_scope = tel_without_scope.where('created_at >= ?', range_start)
    elsif range_end
      tel_with_scope = tel_with_scope.where('created_at <= ?', range_end)
      tel_without_scope = tel_without_scope.where('created_at <= ?', range_end)
    end
    tel_with_counts = tel_with_scope.group(:industry).count
    tel_without_counts = tel_without_scope.group(:industry).count

    # ExtractTrackingを一括取得してN+1を回避（SQLite対応）
    industry_names = @crowdworks.map(&:title)
    all_trackings = ExtractTracking.where(industry: industry_names).order(id: :desc)
    # Ruby側で各業種の最新のtrackingを取得
    latest_trackings = all_trackings.group_by(&:industry).transform_values { |trackings| trackings.first }
    
    @industry_counts = @crowdworks.each_with_object({}) do |crowdwork, hash|
      latest_tracking = latest_trackings[crowdwork.title]
      success_count = latest_tracking&.success_count.to_i
      failure_count = latest_tracking&.failure_count.to_i
      total_count   = latest_tracking&.total_count.to_i
      total = success_count + failure_count
      rate = total.positive? ? (success_count.to_f / total) * 100 : 0.0
      hash[crowdwork.title] = {
        tel_with: tel_with_counts[crowdwork.title] || 0,
        tel_without: tel_without_counts[crowdwork.title] || 0,
        success_count: success_count,
        failure_count: failure_count,
        total_count: total_count,
        rate: rate,
        status: latest_tracking&.status || "抽出前"
      }
    end

    # 業種でフィルタ
    if params[:industry_name].present?
      @customers = @customers.where(industry: params[:industry_name])
    end

    # ページネーション（workerをincludesしてN+1を回避）
    @customers = @customers.includes(:worker).page(params[:page]).per(100)

    # 残り件数取得
    today_total = ExtractTracking
                    .where(created_at: Time.current.beginning_of_day..Time.current.end_of_day)
                    .sum(:total_count)
    daily_limit = ENV.fetch('EXTRACT_DAILY_LIMIT', '500').to_i
    @remaining_extractable = [daily_limit - today_total, 0].max

    elapsed = ((Time.current - start_time) * 1000).round(2)
    Rails.logger.info("draft action: completed in #{elapsed}ms")
  end

  def extract_company_info
    start_time = Time.current
    Rails.logger.info("extract_company_info called (SYNC MODE).")
    industry_name = params[:industry_name]
    total_count = params[:count]

    tracking = ExtractTracking.create!(
      industry:       industry_name,
      total_count:    total_count,
      success_count:  0,
      failure_count:  0,
      status:         "抽出中"
    )

    # 同期実行に変更
    # ExtractCompanyInfoWorker.perform_async(tracking.id)
    begin
      ExtractCompanyInfoWorker.new.perform(tracking.id)
      tracking.reload
      
      if tracking.status == "抽出完了"
        flash[:notice] = "抽出処理が正常に完了しました。（#{tracking.success_count}件成功 / #{tracking.failure_count}件失敗）"
      else
        flash[:alert] = "抽出処理が中断または失敗しました。（ステータス: #{tracking.status}）"
      end
    rescue => e
      Rails.logger.error("Sync execution failed: #{e.message}")
      flash[:alert] = "システムエラーにより抽出処理が失敗しました。"
    end

    elapsed = ((Time.current - start_time) * 1000).round(2)
    Rails.logger.info("extract_company_info: completed in #{elapsed}ms (tracking_id: #{tracking.id})")
    redirect_to draft_path
  end

  # 進捗取得API（ポーリング用）
  # GET /draft/progress.json?industry=業界名
  # industryパラメータが指定されていない場合、全業種の進捗を返す
  def extract_progress
    # ポーリング用のため、キャッシュを無効化
    response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate'
    response.headers['Pragma'] = 'no-cache'
    response.headers['Expires'] = '0'
    
    industry = params[:industry].to_s.presence
    
    if industry
      # 後方互換性のため、industryパラメータが指定されている場合は既存の動作を維持
      tracking = ExtractTracking.where(industry: industry).order(id: :desc).first
      if tracking
        render json: tracking.progress_payload
      else
        render json: { message: 'no_tracking' }
      end
    else
      # 全業種の進捗を返す（N+1クエリを回避）
      crowdworks = Crowdwork.all || []
      industry_names = crowdworks.map(&:title)
      
      # 各業種の最新のtrackingを一括取得
      all_trackings = ExtractTracking.where(industry: industry_names).order(id: :desc)
      latest_trackings = all_trackings.group_by(&:industry).transform_values { |trackings| trackings.first }
      
      progress_data = {}
      crowdworks.each do |crowdwork|
        tracking = latest_trackings[crowdwork.title]
        if tracking
          progress_data[crowdwork.title] = tracking.progress_payload
        else
          progress_data[crowdwork.title] = { message: 'no_tracking' }
        end
      end
      
      render json: progress_data
    end
  end


  def filter_by_industry
    # crowdworkタイトルの初期化
    @crowdworks = Crowdwork.all || []

    # 期間パラメータの解釈（未指定可）
    @period_start = nil
    @period_end   = nil
    if params[:period_start].present?
      begin
        @period_start = Date.parse(params[:period_start])
      rescue ArgumentError
        @period_start = nil
      end
    end
    if params[:period_end].present?
      begin
        @period_end = Date.parse(params[:period_end])
      rescue ArgumentError
        @period_end = nil
      end
    end

    # 期間の整合性（逆転していたら入れ替え）
    if @period_start.present? && @period_end.present? && @period_end < @period_start
      @period_start, @period_end = @period_end, @period_start
    end
    range_start = @period_start&.beginning_of_day
    range_end   = @period_end&.end_of_day

    # タイトルによるフィルタリング
    industry_name = params[:industry_name]
    base_query = Customer.where(status: "draft")
    if range_start && range_end
      base_query = base_query.where(created_at: range_start..range_end)
    elsif range_start
      base_query = base_query.where('created_at >= ?', range_start)
    elsif range_end
      base_query = base_query.where('created_at <= ?', range_end)
    end
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

    # タイトルごとの件数を計算（期間条件があれば適用）
    tel_with_scope = Customer.where(status: "draft").where.not(tel: [nil, '', ' '])
    tel_without_scope = Customer.where(status: "draft").where(tel: [nil, '', ' '])
    if range_start && range_end
      tel_with_scope = tel_with_scope.where(created_at: range_start..range_end)
      tel_without_scope = tel_without_scope.where(created_at: range_start..range_end)
    elsif range_start
      tel_with_scope = tel_with_scope.where('created_at >= ?', range_start)
      tel_without_scope = tel_without_scope.where('created_at >= ?', range_start)
    elsif range_end
      tel_with_scope = tel_with_scope.where('created_at <= ?', range_end)
      tel_without_scope = tel_without_scope.where('created_at <= ?', range_end)
    end
    tel_with_counts = tel_with_scope.group(:industry).count
    tel_without_counts = tel_without_scope.group(:industry).count

    # ExtractTrackingを一括取得してN+1を回避（SQLite対応）
    industry_names = @crowdworks.map(&:title)
    all_trackings = ExtractTracking.where(industry: industry_names).order(id: :desc)
    # Ruby側で各業種の最新のtrackingを取得
    latest_trackings = all_trackings.group_by(&:industry).transform_values { |trackings| trackings.first }

    @industry_counts = @crowdworks.each_with_object({}) do |crowdwork, hash|
      latest_tracking = latest_trackings[crowdwork.title]
      success_count = latest_tracking&.success_count.to_i
      failure_count = latest_tracking&.failure_count.to_i
      total_count   = latest_tracking&.total_count.to_i
      total = success_count + failure_count
      rate = total.positive? ? (success_count.to_f / total) * 100 : 0.0
      hash[crowdwork.title] = {
        tel_with: tel_with_counts[crowdwork.title] || 0,
        tel_without: tel_without_counts[crowdwork.title] || 0,
        success_count: success_count,
        failure_count: failure_count,
        total_count: total_count,
        rate: rate,
        status: latest_tracking&.status || "抽出前"
      }
    end

    # ページネーション
    @customers = @customers.page(params[:page]).per(100)

    # 残り件数取得
    today_total = ExtractTracking
                    .where(created_at: Time.current.beginning_of_day..Time.current.end_of_day)
                    .sum(:total_count)
    daily_limit = ENV.fetch('EXTRACT_DAILY_LIMIT', '500').to_i
    @remaining_extractable = [daily_limit - today_total, 0].max

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

      existing_customer = Customer.where(industry: customer.industry, status: nil) # 公開中のみ
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
          # APP・永久NG・見込 の場合は再掲載しない
          unless %w(APP 永久NG 見込).include?(latest_call.statu)
            existing_customer.calls.create(statu: '再掲載')

            if customer.worker.present?
              customer.worker.increment!(:deleted_customer_count)
            end

            customer.destroy
            reposted_count += 1
            next
          end
        end

        # 再掲載しない場合は単純削除
        if customer.worker.present?
          customer.worker.increment!(:deleted_customer_count)
        end

        customer.destroy
        deleted_count += 1
        next
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
        :next_date,
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
