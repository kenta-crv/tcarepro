class CountsController < ApplicationController
  before_action :load_customer
  before_action :load_count, only: [:edit,:update,:show,:destroy]

  def load_customer
    last_count_customer_ids = nil
    @last_count_params = {}
    if params[:last_count] && !params[:last_count].values.all?(&:blank?)
      @last_count_params = params[:last_count]
      last_count = count.joins_last_count
      last_count = last_count.where(statu: @last_count_params[:statu]) if !@last_count_params[:statu].blank?
      last_count = last_count.where("counts.time >= ?", @last_count_params[:time_from]) if !@last_count_params[:time_from].blank?
      last_count = last_count.where("counts.time <= ?", @last_count_params[:time_to]) if !@last_count_params[:time_to].blank?
      last_count = last_count.where("counts.created_at >= ?", @last_count_params[:created_at_from]) if !@last_count_params[:created_at_from].blank?
      last_count = last_count.where("counts.created_at <= ?", @last_count_params[:created_at_to]) if !@last_count_params[:created_at_to].blank?
      last_count_customer_ids = last_count.pluck(:customer_id)
    end
    @customer = Customer.find(params[:customer_id])
    @count = Count.new
    @q = Customer.ransack(params[:q]) || Customer.ransack(params[:last_count])
    @customers = @q.result || @q.result.includes(:last_count)
    @customers = @customers.where( id: last_count_customer_ids )  if !last_count_customer_ids.nil?
    @next_customer = @customers.where("customers.id > ?", @customer.id).first
    @is_auto_count = (params[:is_auto_count] == 'true')
  end

  def load_count
    @count = Count.find(params[:id])
  end

  def edit
  end

  def create
    @count = @customer.counts.new(count_params)
    @count.save
    #@count.update_attribute(:customer_tel, @customer.tel)
    redirect_to customer_path(id: @next_customer.id, q: params[:q]&.permit!, last_count: params[:last_count]&.permit!)
  end

  def update
    if @count.update(count_params)
      redirect_to customer_path(id: @customer.id, q: params[:q]&.permit!, last_count: params[:last_count]&.permit!)
    else
      render 'edit'
    end
  end

  def destroy
    @customer = Customer.find(params[:customer_id])
    @count = @customer.counts.find(params[:id])
    @count.destroy
    redirect_to customer_path(id: @customer.id, q: params[:q]&.permit!)
  end

  private
 	def count_params
 		params.require(:count).permit(
    :company,
    :title,
    :statu,
    :time,
    :comment
    )
     &.merge(sender: current_sender)
 	end
end
