class ImagesController < ApplicationController
  def create
    @crm = Crm.find(params[:crm_id])
    @image = @crm.images.create
    redirect_to crm_path(@crm)
  end


  def destroy
    @crm = Crm.find(params[:crm_id])
    @image = @crm.images.find(params[:id])
    @image.destroy
    redirect_to crm_path(@crm)
  end

  private
  def image_params
    params.require(:comment).permit(
      :name,
      :views,
      :image
    )
  end
end
