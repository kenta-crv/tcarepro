require 'rubygems'
class CustomersController < ApplicationController
  #before_action :authenticate_admin! || :authenticate_user!

  def index
    last_call_customer_ids = nil
    @last_call_params = {}
    if params[:last_call] && !params[:last_call].values.all?(&:blank?)
      @last_call_params = params[:last_call]
      last_call = Call.joins_last_call
      last_call = last_call.where(statu: @last_call_params[:statu]) if !@last_call_params[:statu].blank?
      last_call = last_call.where("calls.time >= ?", @last_call_params[:time_from]) if !@last_call_params[:time_from].blank?
      last_call = last_call.where("calls.time <= ?", @last_call_params[:time_to]) if !@last_call_params[:time_to].blank?
      last_call = last_call.where("calls.created_at >= ?", @last_call_params[:created_at_from]) if !@last_call_params[:created_at_from].blank?
      last_call = last_call.where("calls.created_at <= ?", @last_call_params[:created_at_to]) if !@last_call_params[:created_at_to].blank?
      last_call_customer_ids = last_call.pluck(:customer_id)
    end
    #@q = Customer.ransack(params[:q]) or @customers.where( id: last_call_customer_ids )  if !last_call_customer_ids.nil?
    @q = Customer.ransack(params[:q]) || Customer.ransack(params[:last_call])
    @customers = @q.result || @q.result.includes(:last_call)
    #@q = Customer.ransack(params[:last_call])
    #@customers = @q.result  @q.result.includes(:last_call)
    #@customers = @q.result.includes(:last_call)
    @customers = @customers.where( id: last_call_customer_ids )  if !last_call_customer_ids.nil?
    @customers = @customers.page(params[:page]).per(30)
    respond_to do |format|
     format.html
     format.csv{ send_data @customers.generate_csv, filename: "customers-#{Time.zone.now.strftime('%Y%m%d%S')}.csv" }
    end
  end


  def show
    last_call_customer_ids = nil
    @last_call_params = {}
    if params[:last_call] && !params[:last_call].values.all?(&:blank?)
      @last_call_params = params[:last_call]
      last_call = Call.joins_last_call
      last_call = last_call.where(statu: @last_call_params[:statu]) if !@last_call_params[:statu].blank?
      last_call = last_call.where("calls.time >= ?", @last_call_params[:time_from]) if !@last_call_params[:time_from].blank?
      last_call = last_call.where("calls.time <= ?", @last_call_params[:time_to]) if !@last_call_params[:time_to].blank?
      last_call = last_call.where("calls.created_at >= ?", @last_call_params[:created_at_from]) if !@last_call_params[:created_at_from].blank?
      last_call = last_call.where("calls.created_at <= ?", @last_call_params[:created_at_to]) if !@last_call_params[:created_at_to].blank?
      last_call_customer_ids = last_call.pluck(:customer_id)
    end
    @customer = Customer.find(params[:id])
    @q = Customer.ransack(params[:q]) || Customer.ransack(params[:last_call])
    @customers = @q.result || @q.result.includes(:last_call)
    @customers = @customers.where( id: last_call_customer_ids )  if !last_call_customer_ids.nil?
    @call = Call.new
    @prev_customer = @customers.where("customers.id < ?", @customer.id).last
    @next_customer = @customers.where("customers.id > ?", @customer.id).first
    @is_auto_call = (params[:is_auto_call] == 'true')
  end

  def new
    @customer = Customer.new
  end

  def create
    @customer = Customer.new(customer_params)
     if @customer.save
       redirect_to customers_path
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
        redirect_to customers_path
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
   @calls = Call.all
   @customers =  Customer.all
   @customers_app = @customers.where(call_id: 1)
   #today
   @call_count_today  = @calls.where.not(admin_id: 1).where('created_at > ?', Time.current.beginning_of_day).where('created_at < ?', Time.current.end_of_day).count
   @protect_count_today = @calls.where.not(admin_id: 1).where(statu: "見込").where('created_at > ?', Time.current.beginning_of_day).where('created_at < ?', Time.current.end_of_day).count
   @protect_convertion_today = (@protect_count_today.to_f / @call_count_today.to_f) * 100
   @app_count_today = @calls.where.not(admin_id: 1).where(statu: "APP").where('created_at > ?', Time.current.beginning_of_day).where('created_at < ?', Time.current.end_of_day).count
   @app_convertion_today = (@app_count_today.to_f / @call_count_today.to_f) * 100
   #week
   @call_count_week  = @calls.where.not(admin_id: 1).where('created_at > ?', Time.current.beginning_of_week).where('created_at < ?', Time.current.end_of_week).count
   @protect_count_week = @calls.where.not(admin_id: 1).where(statu: "見込").where('created_at > ?', Time.current.beginning_of_week).where('created_at < ?', Time.current.end_of_week).count
   @protect_convertion_week = (@protect_count_week.to_f / @call_count_week.to_f) * 100
   @app_count_week = @calls.where.not(admin_id: 1).where(statu: "APP").where('created_at > ?', Time.current.beginning_of_week).where('created_at < ?', Time.current.end_of_week).count
   @app_convertion_week = (@app_count_week.to_f / @call_count_week.to_f) * 100
   #month
   @call_count_month = @calls.where.not(admin_id: 1).where('created_at > ?', Time.current.beginning_of_month).where('created_at < ?', Time.current.end_of_day).count
   @protect_count_month = @calls.where.not(admin_id: 1).where(statu: "見込").where('created_at > ?', Time.current.beginning_of_month).where('created_at < ?', Time.current.end_of_month).count
   @protect_convertion_month = (@protect_count_month.to_f / @call_count_month.to_f) * 100
   @app_count_month = @calls.where.not(admin_id: 1).where(statu: "APP").where('created_at > ?', Time.current.beginning_of_month).where('created_at < ?', Time.current.end_of_month).count
   @app_convertion_month = (@app_count_month.to_f / @call_count_month.to_f) * 100
   @admins = Admin.all
   #statu内容簡素化
   @call_count = @calls.where.not(admin_id: 1).where('created_at > ?', Time.current.beginning_of_month).where('created_at < ?', Time.current.end_of_day)


   #today = Time.zone.today
   #all_monday = today.all_month.select(&:monday?)
   #all_monday_all_day = all_monday.map(&:all_day)
   #@call_count_month_monday = @calls.where.not(admin_id: 1).where(created_at: all_monday_all_day)

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
 end

 def import
   cnt = Customer.import(params[:file])
   redirect_to customers_url, notice:"#{cnt}件登録されました。"
 end

 def call_import
   cnt = Call.call_import(params[:call_file])
   redirect_to customers_url, notice:"#{cnt}件登録されました。"
 end

  private
    def customer_params
      params.require(:customer).permit(
        :company, #会社名
        :store, #店舗名  #
        :first_name, #代表者
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
        :remarks, #備考
        :status, #ステータス
        :memo_1, #ステータス
        :memo_2, #ステータス
        :memo_3, #ステータス
        :memo_4, #ステータス
        :choice, #会社分類
        :old_date, #インポート前コール日
        :title, #取得タイトル
        :old_statu, #古いステータス
        :other, #その他
        :url_2, #url2
        :extraction_date, #抽出日
        :customer_tel
       )
    end

end
