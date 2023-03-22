class SenderController < ApplicationController
  before_action :authenticate_sender!

  def show
    @form = SenderForm.new(
      sender: current_sender,
      year: params[:year]&.to_i || Time.zone.now.year,
      month: params[:month]&.to_i || Time.zone.now.month,
    )
    @data = AutoformResult.where(sender_id:params[:id])
  end
  
end
