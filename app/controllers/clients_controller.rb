class ClientsController < ApplicationController
  before_action :authenticate_client!

  def show
    @form = ClientsForm.new(
      client_params.merge(
        industry: current_client.industry
      )
    )
  end

  private

  def client_params
    params.fetch(:clients_form, {}).permit(:year, :month, :day)
  end
end
