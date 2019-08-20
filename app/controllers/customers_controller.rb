class CustomersController < ApplicationController
  #before_action :authenticate_admin!

  def index
    last_call_customer_ids = nil
    @last_call_params = {}
    if !params[:last_call].blank?
      @last_call_params = params[:last_call]
      last_call = Call.joins_last_call
      last_call = last_call.where(statu: @last_call_params[:statu]) if !@last_call_params[:statu].blank?
      last_call = last_call.where("calls.created_at >= ?", @last_call_params[:created_at_from]) if !@last_call_params[:created_at_from].blank?
      last_call = last_call.where("calls.created_at <= ?", @last_call_params[:created_at_to]) if !@last_call_params[:created_at_to].blank?
      last_call_customer_ids = last_call.pluck(:customer_id)
    end

    @type = params[:type]
    @q = Customer.ransack(params[:q])
    @customers = @q.result
    @customers = @customers.where( id: last_call_customer_ids )  if !last_call_customer_ids.nil?
    @customers = @customers.page(params[:page]).per(100)

    case @type
    when "call" then
      @customers = @q.result.where(status: "call").page(params[:page]).per(100)
    when "prospect" then
      @customers = @q.result.where(status: "prospect").page(params[:page]).per(100)
    when "crm" then
      @customers = @q.result.where(status: "crm").page(params[:page]).per(100)
    else
      @customers = @q.result.page(params[:page]).per(100)
   end

   respond_to do |format|
     format.html
     format.csv{ send_data @customers.generate_csv, filename: "tasks-#{Time.zone.now.strftime('%Y%m%d%S')}.csv" }
   end
  end

  def show
    @customer = Customer.find(params[:id])
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

 def import
   Customer.import(params[:file])
   redirect_to customers_url, notice:"リストを追加しました"
 end

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
        :status #ステータス
       )
    end

end
