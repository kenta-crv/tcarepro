class PrefecturesController < ApplicationController

	def index
		@prefectures = Prefecture.all.order(created_at: 'desc')
	end
	
	def show
  		@prefecture = Prefecture.find(params[:id])
    end
  
    def new
    	@prefecture = Prefecture.new
    end
	
	def create
    @prefecture = Prefecture.new(prefecture_params)
    if @prefecture.save
        # redirect
        redirect_to prefectures_path
    else
        render 'new'
    end
  end
  
  def edit
    @prefecture = Prefecture.find(params[:id])
  end

 def update
    @prefecture = Prefecture.find(params[:id])
     if @prefecture.update(prefecture_params)
        redirect_to prefectures_path
    else
        render 'edit'
    end      
 end
 
 def destroy
    @prefecture = Prefecture.find(params[:id])
    @prefecture.destroy
    redirect_to prefectures_path
 end

  private
    def prefecture_params
      params.require(:prefecture).permit(
    :labor, #労働局
    :product_type, #助成金
    :method, #提出方法
    :tel, #電話番号
    :post, #郵便番号
    :address, #住所
    :point #注意点
)
    end    

end
