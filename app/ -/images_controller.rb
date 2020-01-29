class ImagesController < ApplicationController

  def create
    @crm = Crm.find(params[:crm_id])
    @image = @crm.images.create(image_params)
    redirect_to crm_path(@crm)
  end

  def destroy
    @crm = Crm.find(params[:crm_id])
    @image = @crm.images.find(params[:id])
    @image.destroy
    redirect_to crm_path(@crm)
  end

  def download
    @image = Image.find(params[:id].to_i)
    filepath = @image.image.current_path
    stat = File::stat(filepath)
    send_file(filepath, :filename => @image.image.url.gsub(/.*\//,''), :length => stat.size)
  end

  def view
    @image = Image.find(params[:id].to_i)
    filepath = @image.image.current_path
    stat = File::stat(filepath)
    send_file(filepath, :filename => @image.file.url.gsub(/.*\//,''), :length => stat.size, :disposition => 'inline')
  end

  private
  def image_params
    params.require(:image).permit(
      :name,
      :views,
      :image
    )
  end
end
