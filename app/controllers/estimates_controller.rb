class EstimatesController < ApplicationController
  before_action :authenticate_admin!

  def index
		@estimates = Estimate.all
    @customers = Customer.all
	end

	def show
  	@estimate = Estimate.find(params[:id])
  end

  def new
    @customer = Customer.find(params[:customer_id])
  	@estimate = Estimate.new(customer: @customer)
  end

	def create
    @customer = Customer.find_by(customer_id: params[:customer_id])
    @estimate = Estimate.new
    if  @estimate.save
        redirect_to estimates_path
    else
        render 'new'
    end
  end

  def edit
    @estimate = Estimate.find(params[:id])
  end

 def update
    @customer = Customer.find_by(customer_id: params[:customer_id])
    @estimate = @customer.estimates.find(params[:id])
     if @estimate.update(estimate_params)
        redirect_to estimates_path
    else
        render 'edit'
    end
 end

 def destroy
    @estimate = Estimate.find(params[:id])
    @estimate.destroy
    redirect_to estimates_path
 end

private
 def estimate_params
  params.require(:estimate).permit(
    :status, #ステータス
    :deadline, #期限
    :payment, #入金日
    :subject, #件名
    :item1, #商品名
    :item2, #商品名
    :item3, #商品名
    :item4, #商品名
    :item5, #商品名
    :price1, #商品名
    :price2, #商品名
    :price3, #商品名
    :price4, #商品名
    :price5, #商品名

    :quantity1, #数量
    :quantity2, #数量
    :quantity3, #数量
    :quantity4, #数量
    :quantity5 #数量
    )
  end
end
