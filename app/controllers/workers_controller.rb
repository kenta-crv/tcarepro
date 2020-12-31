class WorkersController < ApplicationController
  def show
    @worker = Workers.find(params[:id])
  end
end
