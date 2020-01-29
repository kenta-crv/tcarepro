class AcquisitionsController < ApplicationController
  #def show
  #  @acquisiton = Acquisition.find(params[:id])
  #end

  def create
    @crm = Crm.find(params[:crm_id])
    @acquisition = @crm.acquisitions.create(acquisition_params)
    redirect_to crm_path(@crm)
  end

  def destroy
    @crm = Crm.find(params[:crm_id])
    @acquisition = @crm.acquisitions.find(params[:id])
    @acquisition.destroy
    redirect_to crm_path(@crm)
  end

  def acquisition_params
    params.require(:acquisition).permit(
      :company, #会社名
      :day, #獲得日
      :name, #獲得者
      :statu #ステータス
    )
  end
end
