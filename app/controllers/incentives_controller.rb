class IncentivesController < ApplicationController
  def update
    incentive = Incentive.find_or_initialize_by(
      customer_summary_key: params[:customer_summary_key],
      year: params[:year],
      month: params[:month]
    )

    incentive.attributes = incentive_params

    incentive.save!

    redirect_to request.referer
  end

  private

  def incentive_params
    params.require(:incentive).permit(:value)
  end
end
