class AdminsController < ApplicationController
  def show
    @admin = Admin.find(params[:id])
    @senders = Sender.all
    @workers = Worker.all
  end
end
