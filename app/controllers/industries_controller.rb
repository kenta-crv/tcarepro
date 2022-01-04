class IndustriesController < ApplicationController
  def update
    industry = Industry.find_or_initialize_by(key: params[:key])

    industry.attributes = industry_params

    industry.save!

    redirect_to request.referer
  end

  private

  def industry_params
    params.require(:industry).permit(:incentive)
  end
end
