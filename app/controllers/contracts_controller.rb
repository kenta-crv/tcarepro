class ContractsController < ApplicationController
  before_action :authenticate_user!
  before_action :authenticate_admin!, only: [:edit, :new]
    def index
      @contracts = Contract.all
    end

    def show
      @contract = Contract.find(params[:id])
    end

    def new
      @contract = Contract.new
    end

    def create
      @contract = Contract.new(contract_params)
      if @contract.save
        redirect_to contracts_path
      else
        render 'new'
      end
    end

    def edit
      @contract = Contract.find(params[:id])
    end

    def destroy
      @contract = Contract.find(params[:id])
      @contract.destroy
       redirect_to contracts_path
    end

    def update
      @contract = Contract.find(params[:id])
      if @contract.update(contract_params)
        redirect_to contracts_path
      else
        render 'edit'
      end
    end

    private
    def contract_params
      params.require(:contract).permit(
        :company,
        :service,
        :search_1,
        :target_1,
        :search_2,
        :target_2,
        :search_3,
        :target_3,
        :slack_account,
        :slack_id,
        :slack_pass,
        :area,
        :sales,
        :calender,
        :otherz
        )
    end
end
