class FaqsController < ApplicationController
  before_action :authenticate_admin!
  def show
    @faq = Faq.find(params[:id])
  end

  def create
    @crm = Crm.find(params[:crm_id])
    @faq = @crm.faqs.create(faq_params)
    redirect_to crm_path(@crm)
  end

  def destroy
    @crm = Crm.find(params[:crm_id])
    @faq = @crm.faqs.find(params[:id])
    @faq.destroy
    redirect_to crm_path(@crm)
  end

  def faq_params
    params.require(:faq).permit(
      :question,
      :select,
      :answer
    )
  end
end
