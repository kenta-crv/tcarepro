class ContractsController < ApplicationController
  before_action :authenticate_user!
  before_action :authenticate_admin!, only: [:edit, :new]
  before_action :set_customer, only: [:new, :create, :edit, :update, :destroy]
  before_action :set_contract, only: [:show, :edit, :update, :destroy]

  def index
    @contracts = Contract.all
  end

  def show
  end

  def new
    @contract = Contract.new
  end

  def create
    @contract = @customer.contracts.new
    @contract.search = {
      keyword1: params[:contract][:search_keyword1],
      keyword2: params[:contract][:search_keyword2]
    }
    @contract.target = {
      target1: params[:contract][:target_target1],
      target2: params[:contract][:target_target2]
    }
  
    if @contract.save
      redirect_to customer_contracts_path(@customer), notice: 'Contract was successfully created.'
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @contract.update(contract_params)
      redirect_to customer_contracts_path(@customer), notice: 'Contract was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @contract.destroy
    redirect_to customer_contracts_path(@customer), notice: 'Contract was successfully destroyed.'
  end

  private

  def set_customer
    @customer = Customer.find(params[:customer_id])
  end

  def set_contract
    @contract = Contract.find_by(id: params[:id])
    redirect_to customer_contracts_path(@customer), alert: 'Contract not found.' unless @contract
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
        :slack_password,
        :area,
        :sales,
        :calender,
        :other,
        :price,
        :upper,
        :payment,
        :statu,
        search: {},
        target: {},
        )
    end
end
