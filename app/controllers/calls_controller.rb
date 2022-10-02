class CallsController < ApplicationController
  before_action :load_customer
  before_action :load_call, only: [:edit,:update,:show,:destroy]
  #before_action :authenticate_admin!

  def load_customer
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
    @customer = Customer.find(params[:customer_id])
    @call = Call.new
    @q = Customer.ransack(params[:q]) || Customer.ransack(params[:last_call])
    @customers = @q.result || @q.result.includes(:last_call)
    @customers = @customers.where( id: last_call )  if last_call
    @next_customer = @customers.where("customers.id > ?", @customer.id).first
    @is_auto_call = (params[:is_auto_call] == 'true')
  end

  def load_call
    @call = Call.find(params[:id])
  end

  def edit
  end

  def create
    @call = @customer.calls.new(call_params)
      if @customer.calls.count >= 3
        # 最新のステータスが着信留守3回連続の場合、4回目は永久NGとする
        if @customer.calls.order(created_at: :asc).limit(4).pluck(:statu).all? { |w| w == "着信留守"  }
          if @call.statu == "着信留守"
            @call.statu = "永久NG"
            @call.save
          end
        elsif @customer.calls.order(created_at: :desc).limit(4).pluck(:statu).all? { |w| w == "担当者不在"  }
          if @call.statu == "担当者不在"
            @call.statu = "永久NG"
            @call.save
          end
        end
      end
      @call.save

      if @next_customer
        redirect_to customer_path(
          id: @next_customer.id,
          q: params[:q]&.permit!,
          last_call: params[:last_call]&.permit!
        )
      else
        redirect_to request.referer, notice: 'リスト が終了しました。再度検索し架電を進めてください。'
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
    :sfa_statu,
 		:time, #再コール
 		:comment, #コメント
    :tel,
    :item_select => []
    )&.merge(admin: current_admin)
     &.merge(user: current_user)
 	end
end
