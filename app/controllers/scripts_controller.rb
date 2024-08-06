class ScriptsController < ApplicationController
    def index
      @scripts = Script.order(created_at: "DESC").page(params[:page])
    end
  
    def show
      @script = Script.find(params[:id])
    end

    

    def new
      @contract = Contract.find(params[:contract_id])
      @script = @contract.scripts.new
      @script.company = @contract.company # ここで Contract の company を設定
    end

    def create
      @contract = Contract.find(params[:contract_id])
      @contract.scripts.create(script_params)
      redirect_to contract_path(@contract)
    end
  
    def destroy
      @contract = Contract.find(params[:contract_id])
      @script = @contract.scripts.find(params[:id])
      @script.destroy
      redirect_to contract_path(@contract)
    end

    def edit
      @contract = Contract.find(params[:contract_id])
      @script = @contract.scripts.find(params[:id])
    end
  
    def update
        @contract = Contract.find(params[:contract_id])
        @script = @contract.scripts.find(params[:id])
       if @script.update(script_params)
         redirect_to contract_path(@contract)
       else
          render 'edit'
       end
    end

    private
    def script_params
      params.require(:script).permit(
        :company,
        :name,
        :tel,
        :address,
        :front_talk, #受付トーク
        :first_talk, #ファーストトーク
        :introduction, #自己紹介
        :hearing_1,
        :hearing_2,
        :hearing_3,
        :hearing_4,
        :closing,
        :requirement, #要件
        :price,
        :experience,
        :refund,
        :usp,
        :other_receive_1,
        :other_receive_2,
        :other_receive_3,
        :remarks,
        :title,
        :requirement_title,
        :price_title,
        :experience_title,
        :refund_title,
        :usp_title,
        :other_receive_1_title,
        :other_receive_2_title,
        :other_receive_3_title,
      )
    end
end
