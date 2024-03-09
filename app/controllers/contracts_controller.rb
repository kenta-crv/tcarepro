  class ContractsController < ApplicationController

    def index
      @contracts = Contract.order(created_at: "DESC").page(params[:page])
    end
  
    def show
      @contract = Contract.find(params[:id])
      @scripts = @contract.scripts
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
        redirect_to contracts_path, notice: 'Contract was successfully updated.'
      else
        render 'edit'
      end
    end

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
        :slack_password,
        :area,
        :sales,
        :calender,
        :other,
        :price,
        :upper,
        :payment,
        :statu,
        )
    end
end
