class CallsController < ApplicationController
  before_action :load_customer
  before_action :load_call, only: [:edit,:update,:show,:destroy]
  #before_action :authenticate_admin!

  def load_customer
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
    @customer = Customer.find(params[:customer_id])
    @call = Call.new
    @q = Customer.ransack(params[:q]) || Customer.ransack(params[:last_call])
    @customers = @q.result || @q.result.includes(:last_call)
    @customers = @customers.where( id: last_call_customer_ids )  if !last_call_customer_ids.nil?
    @next_customer = @customers.where("customers.id > ?", @customer.id).first
    @is_auto_call = (params[:is_auto_call] == 'true')
  end

  def load_call
    @call = Call.find(params[:id])
  end

  def edit
  end

  def create
    if @call = @customer.calls.create(call_params)
    #@call.update_attribute(:customer_tel, @customer.tel)
      redirect_to customer_path(id: @next_customer.id, q: params[:q]&.permit!, last_call: params[:last_call]&.permit!)
    end
  end

  def update
    if @call.update(call_params)
      redirect_to customer_path(id: @customer.id, q: params[:q]&.permit!, last_call: params[:last_call]&.permit!)
    else
      render 'edit'
    end
  end

  def destroy
    @customer = Customer.find(params[:customer_id])
    @call = @customer.calls.find(params[:id])
    @call.destroy
    redirect_to customer_path(id: @customer.id, q: params[:q]&.permit!)
  end

  private
 	def call_params
 		params.require(:call).permit(
 		:statu, #ステータス
 		:time, #再コール
 		:comment, #コメント
    :item_select => []
    )&.merge(admin: current_admin)
     &.merge(user: current_user)
 	end
end
