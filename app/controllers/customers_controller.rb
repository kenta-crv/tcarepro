require 'rubygems'

class CustomersController < ApplicationController
  before_action :authenticate_admin!

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
    #@customers_search_orders = Customer.ransack(params[:customers_search_orders])
    @q = Customer.ransack(params[:q])
    @customers = @q.result
    @customers = @customers.where( id: last_call_customer_ids )  if !last_call_customer_ids.nil?
    @customers = @customers.page(params[:page]).per(100)
    @customers_ids = @customers.ids

   respond_to do |format|
     format.html
     format.csv{ send_data @customers.generate_csv, filename: "tasks-#{Time.zone.now.strftime('%Y%m%d%S')}.csv" }
   end

   # @customers_search_orders = CustomersSearchOrder.find(customers_search_order_id)
   # @customers = @customers_search_order.customers.order('published_at, id desc')
  end

  def show
    @customer = Customer.find(params[:id])
    @call = Call.new
    @customer_ids = params[:customer_ids]
    current_index = @customer_ids.index(params[:id].to_s)

    if current_index > 0 && current_index + 1 < @customer_ids.size
      prev_index = current_index - 1
      prev_customer_id = @customer_ids[prev_index]
      @prev_customer = Customer.find_by(id: prev_customer_id)

      next_index = current_index + 1
      next_customer_id = @customer_ids[next_index]
      @next_customer = Customer.find_by(id: next_customer_id)
    elsif current_index == 0
      next_index = current_index + 1
      next_customer_id = @customer_ids[next_index]
      @next_customer = Customer.find_by(id: next_customer_id)
    elsif current_index + 1 == @customer_ids.size
      prev_index = current_index - 1
      prev_customer_id = @customer_ids[prev_index]
      @prev_customer = Customer.find_by(id: prev_customer_id)
    end

    # 自動発信を行うかどうかのフラグ
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

 def import
   Customer.import(params[:file])
   redirect_to customers_url, notice:"リストを追加しました"
 end

 #def prev_customer
  # @q.result.where("id < ?", id).last
 #end

 #def next_xustomer
  # @q.result.where("id < ?", id).last
 #end

  private
    def customer_params
      params.require(:customer).permit(
        :company, #会社名
        :store, #店舗名
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
        :memo1, #ステータス
        :memo2, #ステータス
        :memo3, #ステータス
        :memo4, #ステータス
        :choice
       )
    end
end