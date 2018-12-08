class DetailsController < ApplicationController

	def create
		@prefecture = Prefecture.find(params[:prefecture_id])
		@prefecture.details.create(detail_params)
		redirect_to prefecture_path(@prefecture)	
	end
	
  def edit
       @detail = Detail.find(params[:id])
  end
	
	def destroy
		@prefecture = Prefecture.find(params[:prefecture_id])
		@detail = @prefecture.details.find(params[:id])
		@detail.destroy
		redirect_to prefecture_path(@prefecture)
	end
	
	 def update
      @detail = Detail.find(params[:prefecture_id])
      @detail = @prefecture.details.find(params[:id])
     if @detail.update(detail_params)
       redirect_to prefecture_path(@prefecture)
     else
        render 'edit'
     end
  	end

	
		private
	def detail_params
		params.require(:detail).permit(
	:product_type,
	:method,
	:tel,
	:post,
	:address,
	:point
	)	
    end

end