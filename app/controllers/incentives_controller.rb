class IncentivesController < ApplicationController
  def show
    @form = IncentiveForm.new(
      year: params[:year],
      month: params[:month]
    )
  end

  def update
    @form = IncentiveForm.new(
      year: params[:year],
      month: params[:month],
      industries: params.require(:industries),
    )

    ActiveRecord::Base.transaction do
      @form.save!
    end

    redirect_to information_path(
      type: 'analy3',
      information_analytic_form: {
        year: @form.year,
        month: @form.month
      }
    )
  end
end
