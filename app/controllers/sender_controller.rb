class SenderController < ApplicationController
  layout "send"
  before_action :authenticate_sender!
  def show
    @form = SenderForm.new(
      sender: current_sender,
      year: params[:year]&.to_i || Time.zone.now.year,
      month: params[:month]&.to_i || Time.zone.now.month,
    )
  end

  def question
  end
end
