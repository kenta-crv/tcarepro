class SendersController < ApplicationController
  def show
    @sender = Sender.find(params[:id])
  end
end
