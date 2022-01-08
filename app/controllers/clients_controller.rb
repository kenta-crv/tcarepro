class ClientsController < ApplicationController
  def show
    @client = Client.find(params[:id])
    @customer = Customer.all
    @call = Call.all
  end
end
