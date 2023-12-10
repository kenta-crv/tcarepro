class ScriptsController < ApplicationController
    def index
      @scripts = Script.order(created_at: "DESC").page(params[:page])
    end
  
    def show
      @script = Script.find(params[:id])
    end
  
    def new
      @script = Script.new
    end
  
    def create
      @script = Script.new(script_params)
      if @script.save
        redirect_to scripts_path
      else
        render 'new'
      end
    end

    def edit
      @script = Script.find(params[:id])
    end
  
    def destroy
      @script = Script.find(params[:id])
      @script.destroy
       redirect_to scripts_path
    end
  
    def update
      @script = Script.find(params[:id])
      if @script.save
        ScriptMailer.second_received_email(@script).deliver
        ScriptMailer.second_send_email(@script).deliver
        redirect_to second_thanks_scripts_path
      else
        render 'new'
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
        :remarks
      )
    end
end
