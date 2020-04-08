class CallsController < ApplicationController
  before_action :load_customer
  before_action :load_call, only: [:edit,:update,:show,:destroy]
  #before_action :authenticate_admin!

  def load_customer
    @customer = Customer.find(params[:customer_id])
    @q = Customer.ransack(params[:q]).result
    @call = Call.new
    @next_customer = @q.where("customers.id > ?", @customer.id).first
    @is_auto_call = (params[:is_auto_call] == 'true')
  end

  def load_call
    @call = Call.find(params[:id])
  end

  def edit
  end

  def create
    if @call = @customer.calls.create(call_params)
    @call.update_attribute(:customer_tel, @customer.tel)
      redirect_to customer_path(id: @next_customer.id, q: params[:q]&.permit!)
    end
  end

  def update
    if @call.update(call_params)
      redirect_to customer_path(id: @customer.id, q: params[:q]&.permit!)
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
    )&.merge(admin: current_admin)&.merge(user: current_user)
 	end
end
