class ImagesController < ApplicationController

 def create
    @contract = Contract.find(params[:contract_id])
    @contract.images.create(image_params)
    redirect_to contract_path(@contract)
  end

  def destroy
    @contract = Contract.find(params[:contract_id])
    @image = @contract.images.find(params[:id])
    @image.destroy
    redirect_to contract_path(@contract)
  end

  def update
      @contract = Contract.find(params[:contract_id])
      @image = @contract.images.find(params[:id])
     if @image.update(image_params)
       redirect_to contract_path(@contract)
     else
        render 'edit'
     end
  end

  def download
      @image = Image.find(params[:id].to_i)
      filepath = @image.picture.current_path
      stat = File::stat(filepath)
      send_file(filepath, :filename => @image.picture.url.gsub(/.*\//,''), :length => stat.size)
  end

  def view
    @image = Image.find(params[:id].to_i)
    filepath = @image.picture.current_path
    stat = File::stat(filepath)
    send_file(filepath, :filename => @image.picture.url.gsub(/.*\//,''), :length => stat.size, :disposition => 'inline')
  end

  private
    def image_params
      params.require(:image).permit(
        :picture, #その他
        :title
      )
    end
end
