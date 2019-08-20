class FaqsController < ApplicationController
  before_action :authenticate_admin!

  def index
    if #params[:selected]
  	 #@selected = params[:selected]
  	 #@faqs = Faq.where(select: @selected).order(created_at: 'desc')
  	 #@faq = Faq.new(select: @selected)
     @faqs = Faq.all.order(created_at: 'desc')
     @faq = Faq.new
    end
  end

  def show
  	@faq = Faq.find(params[:id])
  end

 def create
    @faq = Faq.new(faq_params)
    if @faq.save
        redirect_to faqs_path(selected: faq_params[:select])
    else
        render 'index'
    end
  end

  def edit
    @faq = Faq.find(params[:id])
  end

 def update
    @faq = Faq.find(params[:id])
    @faq.update(faq_params)
    #  if @faq.update(faq_params)
    #     redirect_to faqs_path
    # else
    #     render 'edit'
    # end
    render 'show'
 end

 def destroy
    @faq = Faq.find(params[:id])
    @faq.destroy
    redirect_to faqs_path
 end

  private
    def faq_params
      params.require(:faq).permit(
      :title,
      :select,
      :contents)
    end
end
