require 'rubygems'
class CustomersController < ApplicationController
  before_action :authenticate_admin!, only: [:destroy, :destroy_all, :anayltics, :import, :call_import, :sfa, :mail]
  before_action :authenticate_worker!, only: [:extraction]
  before_action :authenticate_sender!, only: [:okurite]
  before_action :authenticate_user!, only: [:index]
  before_action :authenticate_worker_or_user, only: [:new, :edit]
  #before_action :authenticate_user_or_admin, only: [:index, :show]
  #before_action :authenticate_worker_or_admin, only: [:extraction]

  def index
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
    #@q = Customer.ransack(params[:q]) or @customers.where( id: last_call_customer_ids )  if !last_call_customer_ids.nil?
    @q = Customer.ransack(params[:q]) || Customer.ransack(params[:last_call])
    #@q = User.ransack(params[:q])
    @customers = @q.result || @q.result.includes(:last_call)
    #@q = Customer.ransack(params[:last_call])
    #@customers = @q.result  @q.result.includes(:last_call)
    #@customers = @q.result.includes(:last_call)
    @customers = @customers.where( id: last_call ) if last_call
    @customers = @customers.distinct.preload(:calls).page(params[:page]).per(30)
    respond_to do |format|
     format.html
     format.csv{ send_data @customers.generate_csv, filename: "customers-#{Time.zone.now.strftime('%Y%m%d%S')}.csv" }
    end
  end

  def show
   if sender_signed_in?
     last_count_customer_ids = nil
     @last_count_params = {}
     if params[:last_count] && !params[:last_count].values.all?(&:blank?)
       @last_count_params = params[:last_count]
       last_count = count.joins_last_count # TODO: count は存在しない。未使用なら消したい
       last_count = last_count.where(statu: @last_count_params[:statu]) if !@last_count_params[:statu].blank?
       last_count = last_count.where("counts.time >= ?", @last_count_params[:time_from]) if !@last_count_params[:time_from].blank?
       last_count = last_count.where("counts.time <= ?", @last_count_params[:time_to]) if !@last_count_params[:time_to].blank?
       last_count = last_count.where("counts.created_at >= ?", @last_count_params[:created_at_from]) if !@last_count_params[:created_at_from].blank?
       last_count = last_count.where("counts.created_at <= ?", @last_count_params[:created_at_to]) if !@last_count_params[:created_at_to].blank?
       last_count_customer_ids = last_count.pluck(:customer_id)
     end
     @customer = Customer.find(params[:id])
     @q = Customer.ransack(params[:q]) || Customer.ransack(params[:last_count])
     @customers = @q.result || @q.result.includes(:last_count)
     @customers = @customers.where( id: last_count_customer_ids )  if !last_count_customer_ids.nil?
     @count = Count.new
     @prev_customer = @customers.where("customers.id < ?", @customer.id).last
     @next_customer = @customers.where("customers.id > ?", @customer.id).first
     @is_auto_count = (params[:is_auto_count] == 'true')
   else
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
         redirect_to customers_path
       end
     else
       render 'new'
     end
  end

  def complete
    @customer = Customer.find_by(params[:id])
    if @customer.valid?
        CustomerMailer.receive_email(@customer).deliver
        CustomerMailer.send_email(@customer).deliver
        flash[:notice] = "資料を送付しました"
    else
        flash[:notice] = "資料を送付しました"
    end
  end

  def edit
    @customer = Customer.find(params[:id])
  end

  def update
    @customers = Customer&.where(worker_id: current_worker.id)
    @count_day = @customers.where('updated_at > ?', Time.current.beginning_of_day).where('updated_at < ?',Time.current.end_of_day).count
    @customer = Customer.find(params[:id])
      if @customer.update(customer_params)
        flash[:notice] = "登録が完了しました。1日あたりの残り作業実施件数は#{30 - @count_day}件です。"
        redirect_to customer_path
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

  def bulk_edit
    @ids = params[:ids]
  end

  def bulk_update
    @ids = params[:ids].split(" ")
    @ids.each do |id|
      c = Customer.find(id.to_i)
      c.update_attributes(
        status: params[:status]
      )
    end
    redirect_to request.referer
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
    when "analy2"
      @calls = Call.all
      @call_ng = @calls.where("statu LIKE ?","%NG%")
      @call_month_basic = @calls.where('created_at > ?', Time.current.beginning_of_month).where('created_at < ?', Time.current.end_of_month).to_a
      @call_count_called = @call_month_basic.select { |call| call.statu == "着信留守" }
      @call_count_absence = @call_month_basic.select { |call| call.statu == "担当者不在" }
      @call_count_prospect = @call_month_basic.select { |call| call.statu == "見込" }
      @call_count_app = @call_month_basic.select { |call| call.statu == "APP" }
      @call_count_cancel = @call_month_basic.select { |call| call.statu == "キャンセル" }
      @call_count_ng = @call_month_basic.select { |call| call.statu == "NG" }
      #9時台
      @call_total_9 = @call_month_basic.select { |call| l(call.created_at, format: :prepare) >= "09:00:00" }.select { |call| l(call.created_at, format: :prepare) < "09:59:59" }.count
      @call_total_b9 = @call_month_basic.select { |call| l(call.created_at, format: :prepare) >= "00:00:00" }.select { |call| l(call.created_at, format: :prepare) < '00:59:59' }.count
      @call_called_9 = @call_count_called.select { |call| l(call.created_at, format: :prepare) >= "09:00:00" }.select { |call| l(call.created_at, format: :prepare) < "09:59:59" }.count
      @call_called_b9 = @call_count_called.select { |call| l(call.created_at, format: :prepare) >= "00:00:00" }.select { |call| l(call.created_at, format: :prepare) < '00:59:59' }.count
      @call_absence_9 = @call_count_absence.select { |call| l(call.created_at, format: :prepare) >= "09:00:00" }.select { |call| l(call.created_at, format: :prepare) < "09:59:59" }.count
      @call_absence_b9 = @call_count_absence.select { |call| l(call.created_at, format: :prepare) >= "00:00:00" }.select { |call| l(call.created_at, format: :prepare) < '00:59:59' }.count
      @call_prospect_9 = @call_count_prospect.select { |call| l(call.created_at, format: :prepare) >= "09:00:00" }.select { |call| l(call.created_at, format: :prepare) < "09:59:59" }.count
      @call_prospect_b9 = @call_count_prospect.select { |call| l(call.created_at, format: :prepare) >= "00:00:00" }.select { |call| l(call.created_at, format: :prepare) < '00:59:59' }.count
      @call_app_9 = @call_count_app.select { |call| l(call.created_at, format: :prepare) >= "09:00:00" }.select { |call| l(call.created_at, format: :prepare) < "09:59:59" }.count
      @call_app_b9 = @call_count_app.select { |call| l(call.created_at, format: :prepare) >= "00:00:00" }.select { |call| l(call.created_at, format: :prepare) < '00:59:59' }.count
      @call_ng_9 = @call_ng.select { |call| l(call.created_at, format: :prepare) >= "09:00:00" }.select { |call| l(call.created_at, format: :prepare) < "09:59:59" }.count
      @call_ng_b9 = @call_ng.select { |call| l(call.created_at, format: :prepare) >= "00:00:00" }.select { |call| l(call.created_at, format: :prepare) < '00:59:59' }.count

      #10時台
      @call_total_10 = @call_month_basic.select { |call| l(call.created_at, format: :prepare) >= "10:00:00" }.select { |call| l(call.created_at, format: :prepare) < "10:59:59" }.count
      @call_total_b10 = @call_month_basic.select { |call| l(call.created_at, format: :prepare) >= "01:00:00" }.select { |call| l(call.created_at, format: :prepare) < "01:59:59" }.count
      @call_called_10 = @call_count_called.select { |call| l(call.created_at, format: :prepare) >= "10:00:00" }.select { |call| l(call.created_at, format: :prepare) < "10:59:59" }.count
      @call_called_b10 = @call_count_called.select { |call| l(call.created_at, format: :prepare) >= "01:00:00" }.select { |call| l(call.created_at, format: :prepare) < "01:59:59" }.count
      @call_absence_10 = @call_count_absence.select { |call| l(call.created_at, format: :prepare) >= "10:00:00" }.select { |call| l(call.created_at, format: :prepare) < "10:59:59" }.count
      @call_absence_b10 = @call_count_absence.select { |call| l(call.created_at, format: :prepare) >= "01:00:00" }.select { |call| l(call.created_at, format: :prepare) < "01:59:59" }.count
      @call_prospect_10 = @call_count_prospect.select { |call| l(call.created_at, format: :prepare) >= "10:00:00" }.select { |call| l(call.created_at, format: :prepare) < "10:59:59" }.count
      @call_prospect_b10 = @call_count_prospect.select { |call| l(call.created_at, format: :prepare) >= "01:00:00" }.select { |call| l(call.created_at, format: :prepare) < "01:59:59" }.count
      @call_app_10 = @call_count_app.select { |call| l(call.created_at, format: :prepare) >= "10:00:00" }.select { |call| l(call.created_at, format: :prepare) < "10:59:59" }.count
      @call_app_b10 = @call_count_app.select { |call| l(call.created_at, format: :prepare) >= "01:00:00" }.select { |call| l(call.created_at, format: :prepare) < "01:59:59" }.count
      @call_ng_10 = @call_ng.select { |call| l(call.created_at, format: :prepare) >= "10:00:00" }.select { |call| l(call.created_at, format: :prepare) < "10:59:59" }.count
      @call_ng_b10 = @call_ng.select { |call| l(call.created_at, format: :prepare) >= "01:00:00" }.select { |call| l(call.created_at, format: :prepare) < '01:59:59' }.count

      #11時台
      @call_total_11 = @call_month_basic.select { |call| l(call.created_at, format: :prepare) >= "11:00:00" }.select { |call| l(call.created_at, format: :prepare) < "11:59:59" }.count
      @call_total_b11 = @call_month_basic.select { |call| l(call.created_at, format: :prepare) >= "02:00:00" }.select { |call| l(call.created_at, format: :prepare) < "02:59:59" }.count
      @call_called_11 = @call_count_called.select { |call| l(call.created_at, format: :prepare) >= "11:00:00" }.select { |call| l(call.created_at, format: :prepare) < "11:59:59" }.count
      @call_called_b11 = @call_count_called.select { |call| l(call.created_at, format: :prepare) >= "02:00:00" }.select { |call| l(call.created_at, format: :prepare) < "02:59:59" }.count
      @call_absence_11 = @call_count_absence.select { |call| l(call.created_at, format: :prepare) >= "11:00:00" }.select { |call| l(call.created_at, format: :prepare) < "11:59:59" }.count
      @call_absence_b11 = @call_count_absence.select { |call| l(call.created_at, format: :prepare) >= "02:00:00" }.select { |call| l(call.created_at, format: :prepare) < "02:59:59" }.count
      @call_prospect_11 = @call_count_prospect.select { |call| l(call.created_at, format: :prepare) >= "11:00:00" }.select { |call| l(call.created_at, format: :prepare) < "11:59:59" }.count
      @call_prospect_b11 = @call_count_prospect.select { |call| l(call.created_at, format: :prepare) >= "02:00:00" }.select { |call| l(call.created_at, format: :prepare) < "02:59:59" }.count
      @call_app_11 = @call_count_app.select { |call| l(call.created_at, format: :prepare) >= "11:00:00" }.select { |call| l(call.created_at, format: :prepare) < "11:59:59" }.count
      @call_app_b11 = @call_count_app.select { |call| l(call.created_at, format: :prepare) >= "02:00:00" }.select { |call| l(call.created_at, format: :prepare) < "02:59:59" }.count
      @call_ng_11 = @call_ng.select { |call| l(call.created_at, format: :prepare) >= "11:00:00" }.select { |call| l(call.created_at, format: :prepare) < "11:59:59" }.count
      @call_ng_b11 = @call_ng.select { |call| l(call.created_at, format: :prepare) >= "02:00:00" }.select { |call| l(call.created_at, format: :prepare) < '02:59:59' }.count

      #13時台
      @call_total_13 = @call_month_basic.select { |call| l(call.created_at, format: :prepare) >= "13:00:00" }.select { |call| l(call.created_at, format: :prepare) < "13:59:59" }.count
      @call_total_b13 = @call_month_basic.select { |call| l(call.created_at, format: :prepare) >= "04:00:00" }.select { |call| l(call.created_at, format: :prepare) < "04:59:59" }.count
      @call_called_13 = @call_count_called.select { |call| l(call.created_at, format: :prepare) >= "13:00:00" }.select { |call| l(call.created_at, format: :prepare) < "13:59:59" }.count
      @call_called_b13 = @call_count_called.select { |call| l(call.created_at, format: :prepare) >= "04:00:00" }.select { |call| l(call.created_at, format: :prepare) < "04:59:59" }.count
      @call_absence_13 = @call_count_absence.select { |call| l(call.created_at, format: :prepare) >= "13:00:00" }.select { |call| l(call.created_at, format: :prepare) < "13:59:59" }.count
      @call_absence_b13 = @call_count_absence.select { |call| l(call.created_at, format: :prepare) >= "04:00:00" }.select { |call| l(call.created_at, format: :prepare) < "04:59:59" }.count
      @call_prospect_13 = @call_count_prospect.select { |call| l(call.created_at, format: :prepare) >= "13:00:00" }.select { |call| l(call.created_at, format: :prepare) < "13:59:59" }.count
      @call_prospect_b13 = @call_count_prospect.select { |call| l(call.created_at, format: :prepare) >= "04:00:00" }.select { |call| l(call.created_at, format: :prepare) < "04:59:59" }.count
      @call_app_13 = @call_count_app.select { |call| l(call.created_at, format: :prepare) >= "13:00:00" }.select { |call| l(call.created_at, format: :prepare) < "13:59:59" }.count
      @call_app_b13 = @call_count_app.select { |call| l(call.created_at, format: :prepare) >= "04:00:00" }.select { |call| l(call.created_at, format: :prepare) < "04:59:59" }.count
      @call_ng_13 = @call_ng.select { |call| l(call.created_at, format: :prepare) >= "13:00:00" }.select { |call| l(call.created_at, format: :prepare) < "13:59:59" }.count
      @call_ng_b13 = @call_ng.select { |call| l(call.created_at, format: :prepare) >= "04:00:00" }.select { |call| l(call.created_at, format: :prepare) < '04:59:59' }.count

      #14時台
      @call_total_14 = @call_month_basic.select { |call| l(call.created_at, format: :prepare) >= "14:00:00" }.select { |call| l(call.created_at, format: :prepare) < "14:59:59" }.count
      @call_total_b14 = @call_month_basic.select { |call| l(call.created_at, format: :prepare) >= "05:00:00" }.select { |call| l(call.created_at, format: :prepare) < "05:59:59" }.count
      @call_called_14 = @call_count_called.select { |call| l(call.created_at, format: :prepare) >= "14:00:00" }.select { |call| l(call.created_at, format: :prepare) < "14:59:59" }.count
      @call_called_b14 = @call_count_called.select { |call| l(call.created_at, format: :prepare) >= "05:00:00" }.select { |call| l(call.created_at, format: :prepare) < "05:59:59" }.count
      @call_absence_14 = @call_count_absence.select { |call| l(call.created_at, format: :prepare) >= "14:00:00" }.select { |call| l(call.created_at, format: :prepare) < "14:59:59" }.count
      @call_absence_b14 = @call_count_absence.select { |call| l(call.created_at, format: :prepare) >= "05:00:00" }.select { |call| l(call.created_at, format: :prepare) < "05:59:59" }.count
      @call_prospect_14 = @call_count_prospect.select { |call| l(call.created_at, format: :prepare) >= "14:00:00" }.select { |call| l(call.created_at, format: :prepare) < "14:59:59" }.count
      @call_prospect_b14 = @call_count_prospect.select { |call| l(call.created_at, format: :prepare) >= "05:00:00" }.select { |call| l(call.created_at, format: :prepare) < "05:59:59" }.count
      @call_app_14 = @call_count_app.select { |call| l(call.created_at, format: :prepare) >= "14:00:00" }.select { |call| l(call.created_at, format: :prepare) < "14:59:59" }.count
      @call_app_b14 = @call_count_app.select { |call| l(call.created_at, format: :prepare) >= "05:00:00" }.select { |call| l(call.created_at, format: :prepare) < "05:59:59" }.count
      @call_ng_14 = @call_ng.select { |call| l(call.created_at, format: :prepare) >= "14:00:00" }.select { |call| l(call.created_at, format: :prepare) < "14:59:59" }.count
      @call_ng_b14 = @call_ng.select { |call| l(call.created_at, format: :prepare) >= "05:00:00" }.select { |call| l(call.created_at, format: :prepare) < '05:59:59' }.count

      #15時台
      @call_total_15 = @call_month_basic.select { |call| l(call.created_at, format: :prepare) >= "15:00:00" }.select { |call| l(call.created_at, format: :prepare) < "15:59:59" }.count
      @call_total_b15 = @call_month_basic.select { |call| l(call.created_at, format: :prepare) >= "06:00:00" }.select { |call| l(call.created_at, format: :prepare) < "06:59:59" }.count
      @call_called_15 = @call_count_called.select { |call| l(call.created_at, format: :prepare) >= "15:00:00" }.select { |call| l(call.created_at, format: :prepare) < "15:59:59" }.count
      @call_called_b15 = @call_count_called.select { |call| l(call.created_at, format: :prepare) >= "06:00:00" }.select { |call| l(call.created_at, format: :prepare) < "06:59:59" }.count
      @call_absence_15 = @call_count_absence.select { |call| l(call.created_at, format: :prepare) >= "15:00:00" }.select { |call| l(call.created_at, format: :prepare) < "15:59:59" }.count
      @call_absence_b15 = @call_count_absence.select { |call| l(call.created_at, format: :prepare) >= "06:00:00" }.select { |call| l(call.created_at, format: :prepare) < "06:59:59" }.count
      @call_prospect_15 = @call_count_prospect.select { |call| l(call.created_at, format: :prepare) >= "15:00:00" }.select { |call| l(call.created_at, format: :prepare) < "15:59:59" }.count
      @call_prospect_b15 = @call_count_prospect.select { |call| l(call.created_at, format: :prepare) >= "06:00:00" }.select { |call| l(call.created_at, format: :prepare) < "06:59:59" }.count
      @call_app_15 = @call_count_app.select { |call| l(call.created_at, format: :prepare) >= "15:00:00" }.select { |call| l(call.created_at, format: :prepare) < "15:59:59" }.count
      @call_app_b15 = @call_count_app.select { |call| l(call.created_at, format: :prepare) >= "06:00:00" }.select { |call| l(call.created_at, format: :prepare) < "06:59:59" }.count
      @call_ng_15 = @call_ng.select { |call| l(call.created_at, format: :prepare) >= "15:00:00" }.select { |call| l(call.created_at, format: :prepare) < "15:59:59" }.count
      @call_ng_b15 = @call_ng.select { |call| l(call.created_at, format: :prepare) >= "06:00:00" }.select { |call| l(call.created_at, format: :prepare) < '06:59:59' }.count

      #16時台
      @call_total_16 = @call_month_basic.select { |call| l(call.created_at, format: :prepare) >= "16:00:00" }.select { |call| l(call.created_at, format: :prepare) < "16:59:59" }.count
      @call_total_b16 = @call_month_basic.select { |call| l(call.created_at, format: :prepare) >= "07:00:00" }.select { |call| l(call.created_at, format: :prepare) < "07:59:59" }.count
      @call_called_16 = @call_count_called.select { |call| l(call.created_at, format: :prepare) >= "16:00:00" }.select { |call| l(call.created_at, format: :prepare) < "16:59:59" }.count
      @call_called_b16 = @call_count_called.select { |call| l(call.created_at, format: :prepare) >= "07:00:00" }.select { |call| l(call.created_at, format: :prepare) < "07:59:59" }.count
      @call_absence_16 = @call_count_absence.select { |call| l(call.created_at, format: :prepare) >= "16:00:00" }.select { |call| l(call.created_at, format: :prepare) < "16:59:59" }.count
      @call_absence_b16 = @call_count_absence.select { |call| l(call.created_at, format: :prepare) >= "07:00:00" }.select { |call| l(call.created_at, format: :prepare) < "07:59:59" }.count
      @call_prospect_16 = @call_count_prospect.select { |call| l(call.created_at, format: :prepare) >= "16:00:00" }.select { |call| l(call.created_at, format: :prepare) < "16:59:59" }.count
      @call_prospect_b16 = @call_count_prospect.select { |call| l(call.created_at, format: :prepare) >= "07:00:00" }.select { |call| l(call.created_at, format: :prepare) < "07:59:59" }.count
      @call_app_16 = @call_count_app.select { |call| l(call.created_at, format: :prepare) >= "16:00:00" }.select { |call| l(call.created_at, format: :prepare) < "16:59:59" }.count
      @call_app_b16 = @call_count_app.select { |call| l(call.created_at, format: :prepare) >= "07:00:00" }.select { |call| l(call.created_at, format: :prepare) < "07:59:59" }.count
      @call_ng_16 = @call_ng.select { |call| l(call.created_at, format: :prepare) >= "16:00:00" }.select { |call| l(call.created_at, format: :prepare) < "16:59:59" }.count
      @call_ng_b16 = @call_ng.select { |call| l(call.created_at, format: :prepare) >= "07:00:00" }.select { |call| l(call.created_at, format: :prepare) < '07:59:59' }.count

      #17時台
      @call_total_17 = @call_month_basic.select { |call| l(call.created_at, format: :prepare) >= "17:00:00" }.select { |call| l(call.created_at, format: :prepare) < "17:59:59" }.count
      @call_total_b17 = @call_month_basic.select { |call| l(call.created_at, format: :prepare) >= "08:00:00" }.select { |call| l(call.created_at, format: :prepare) < "08:59:59" }.count
      @call_called_17 = @call_count_called.select { |call| l(call.created_at, format: :prepare) >= "17:00:00" }.select { |call| l(call.created_at, format: :prepare) < "17:59:59" }.count
      @call_called_b17 = @call_count_called.select { |call| l(call.created_at, format: :prepare) >= "08:00:00" }.select { |call| l(call.created_at, format: :prepare) < "08:59:59" }.count
      @call_absence_17 = @call_count_absence.select { |call| l(call.created_at, format: :prepare) >= "17:00:00" }.select { |call| l(call.created_at, format: :prepare) < "17:59:59" }.count
      @call_absence_b17 = @call_count_absence.select { |call| l(call.created_at, format: :prepare) >= "08:00:00" }.select { |call| l(call.created_at, format: :prepare) < "08:59:59" }.count
      @call_prospect_17 = @call_count_prospect.select { |call| l(call.created_at, format: :prepare) >= "17:00:00" }.select { |call| l(call.created_at, format: :prepare) < "17:59:59" }.count
      @call_prospect_b17 = @call_count_prospect.select { |call| l(call.created_at, format: :prepare) >= "08:00:00" }.select { |call| l(call.created_at, format: :prepare) < "08:59:59" }.count
      @call_app_17 = @call_count_app.select { |call| l(call.created_at, format: :prepare) >= "17:00:00" }.select { |call| l(call.created_at, format: :prepare) < "17:59:59" }.count
      @call_app_b17 = @call_count_app.select { |call| l(call.created_at, format: :prepare) >= "08:00:00" }.select { |call| l(call.created_at, format: :prepare) < "08:59:59" }.count
      @call_ng_17 = @call_ng.select { |call| l(call.created_at, format: :prepare) >= "17:00:00" }.select { |call| l(call.created_at, format: :prepare) < "17:59:59" }.count
      @call_ng_b17 = @call_ng.select { |call| l(call.created_at, format: :prepare) >= "08:00:00" }.select { |call| l(call.created_at, format: :prepare) < '08:59:59' }.count
      @admins = Admin.all
      @users = User.all
      #statu内容簡素化
      @call_count = @calls.where('created_at > ?', Time.current.beginning_of_month).where('created_at < ?', Time.current.end_of_month)
    when "analy3"
      attributes = params.fetch(:information_analytic_form, {}).permit(:user_id, :year, :month)

      @form = InformationAnalyticForm.new(
        user_id: attributes[:user_id].presence,
        year: attributes[:year].presence || Time.current.year,
        month: attributes[:month].presence || Time.current.month,
      )
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
    else
   end
  end

  def news
    @customers =  Customer.all
    @sanzCount = Customer.where("industry LIKE ?", "%サンズ%")
    @factCount = Customer.where("industry LIKE ?", "%ファクト%").where("created_at > ?", Time.zone.now.beginning_of_day).count
    @asia1Count = Customer.where("industry LIKE ?", "%asia（介護）%").where("created_at > ?", Time.zone.now.beginning_of_day).count
    @asia2Count = Customer.where("industry LIKE ?", "%asia（食品）%").where("created_at > ?", Time.zone.now.beginning_of_day).count
    @asia3Count = Customer.where("industry LIKE ?", "%asia（農業）%").where("created_at > ?", Time.zone.now.beginning_of_day).count
    @sorairoCount = Customer.where("industry LIKE ?", "%SORAIRO（工場）%").where("created_at > ?", Time.zone.now.beginning_of_day).count
    @app1Count = Customer.where("industry LIKE ?", "%アポ匠（人材）%").where("created_at > ?", Time.zone.now.beginning_of_day).count
    @app2Count = Customer.where("industry LIKE ?", "%アポ匠（外国人）%").where("created_at > ?", Time.zone.now.beginning_of_day).count
  end

  def import
    cnt = Customer.import(params[:file])
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

  def sfa
    @q = Customer.ransack(params[:q])
    @customers = @q.result
    @customers = @customers.where(choice: "SFA").page(params[:page]).per(20)
  end

  def list
    @q = Customer.ransack(params[:q])
    @customers = @q.result
    @customers = @customers.preload(:calls).order(created_at: 'desc').page(params[:page]).per(20)
  end

  def extraction
    @q = Customer.ransack(params[:q])
    @customers = @q.result
    @customers = @customers.order("created_at DESC").where("created_at > ?", Time.current.beginning_of_day).where("created_at < ?", (Time.current.beginning_of_day + 6.day).at_end_of_day).page(params[:page]).per(20)
    #@customer = Customer.find(params[:id])
  end

  def okurite
    @q = Customer.ransack(params[:q])
    @customers = @q.result
    @customers = @customers.where.not(url: nil).page(params[:page]).per(30)
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
        :business, #事業内容
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
