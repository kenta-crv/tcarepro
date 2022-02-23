class EstimatesController < ApplicationController
  before_action :authenticate_admin!

  def index
    @customers = Customer.all
    @estimates = Estimate.all
	end

	def show
  	@estimate = Estimate.find(params[:id])
  end

  def new
    @customer = Customer.find_by(id: params[:customer_id])
  	@estimate = Estimate.new(customer: @customer)
  end

	def create
    @customer = Customer.find_by(id: params[:customer_id]) #(customer_id: params[:customer_id])としない
    @estimate = Estimate.new(estimate_params) #paramsを忘れない
    @estimate.customer = @customer #
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

   # 帳票出力処理
  def report
    @estimate = Estimate.find(params[:id])
    report = Thinreports::Report.new layout: "app/reports/layouts/invoices.tlf"
    report.start_new_page
    report.page.values(
    created_at: @estimate.try(:created_at),
    company: @estimate.customer.try(:company),
    first_name: @estimate.customer.try(:first_name),
    postnumber: @estimate.customer.try(:postnumber),
    address: @estimate.customer.try(:address),

    item1: @estimate.try(:item1),
    price1: @estimate.try(:price1),
    quantity1: @estimate.try(:quantity1),
    total1: @estimate.try(:calc1),

    item2: @estimate.try(:item2),
    price2: @estimate.try(:price2),
    quantity2: @estimate.try(:quantity2),
    total2: @estimate.try(:calc2),

    item3: @estimate.try(:item3),
    price3: @estimate.try(:price3),
    quantity3: @estimate.try(:quantity3),
    total3: @estimate.try(:calc3),

    item4: @estimate.try(:item4),
    price4: @estimate.try(:price4),
    quantity4: @estimate.try(:quantity4),
    total4: @estimate.try(:calc4),

    item5: @estimate.try(:item5),
    price5: @estimate.try(:price5),
    quantity5: @estimate.try(:quantity5),
    total5: @estimate.try(:calc5),

    subtotal: @estimate.try(:summary),
    tax: @estimate.try(:tax),
    all: @estimate.try(:total),
    all2: @estimate.try(:total),
    )
    send_data(report.generate, filename: "#{@estimate}.pdf", type: "application/pdf")
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
