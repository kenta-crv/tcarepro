class AcquisitionsController < ApplicationController
  #def show
  #  @acquisiton = Acquisition.find(params[:id])
  #end

  def create
    @crm = Crm.find(params[:crm_id])
    @acquisiton = @crm.acquisitons.create(acquisiton_params)
    redirect_to crm_path(@crm)
  end

  def destroy
    @crm = Crm.find(params[:crm_id])
    @acquisiton = @crm.acquisitons.find(params[:id])
    @acquisiton.destroy
    redirect_to crm_path(@crm)
  end

  def acquisition_params
    params.require(:acquisiton).permit(
      :company, #会社名
      :day, #獲得日
      :name, #獲得者
      :statu #ステータス
    )
  end
end
