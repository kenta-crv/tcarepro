class OrdersController < ApplicationController
  def index
		@orders = Order.all.order(created_at: 'desc')
	end

	def show
  	@order = Order.find(params[:id])
  end

  def new
  	@order = Order.new
  end

	def create
    @order = Order.new(order_params)
    if @order.save
        redirect_to orders_path
    else
        render 'new'
    end
  end

  def edit
    @order = Order.find(params[:id])
  end

 def update
    @order = Order.find(params[:id])
    if @order.update(order_params)
        redirect_to orders_path
    else
        render 'edit'
    end
 end

 def destroy
    @order = Order.find(params[:id])
    @order.destroy
    redirect_to orders_path
 end

private
 def order_params
  params.require(:order).permit(
    :title, #題名
    :list, #リスト名
    :tab, #実施タブ
    #リスト制作
    :within, #対象内
    :without, #対象外
    :warning, #注意点
    :remarks, #備考
    #メール送信
    :company, #会社名
    :name, #名前
    :name_kana, #ナマエ
    :tel, #電話番号
    :address, #住所
    :url, #url
    :mail, #mail
    :message #送信内容
      )
  end
end
