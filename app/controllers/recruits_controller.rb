class RecruitsController < ApplicationController
    def index
      @recruits = Recruit.order(created_at: "DESC").page(params[:page])
    end
  
    def show
      @recruit = Recruit.find(params[:id])
    end
  
    def new
      @recruit = Recruit.new
    end
  
    def create
      @recruit = Recruit.new(recruit_params)
      if @recruit.update(recruit_params)
        RecruitMailer.received_email(@recruit).deliver_now
        RecruitMailer.send_email(@recruit).deliver_now
        redirect_to thanks_recruits_path
      else
        flash[:error] = @recruit.errors.full_messages.to_sentence
        render 'edit'
      end
    end
  
    def thanks
    end

    def info
    end

    def offer_email
      recruit = Recruit.find(params[:id])
      RecruitMailer.offer_email(recruit).deliver_now
      redirect_to recruits_path, notice: '採用通知を送信しました'
    end
    
    def reject_email
      recruit = Recruit.find(params[:id])
      RecruitMailer.reject_email(recruit).deliver_now
      redirect_to recruits_path, notice: '不採用通知を送信しました'
    end
  
    def edit
      @recruit = Recruit.find(params[:id])
    end
  
    def destroy
      @recruit = Recruit.find(params[:id])
      @recruit.destroy
      redirect_to recruits_path
    end
  
    def update
      @recruit = Recruit.find(params[:id])
      if @recruit.update(recruit_params) # Strong Parametersを使用
        RecruitMailer.second_received_email(@recruit).deliver_now
        RecruitMailer.second_send_email(@recruit).deliver_now
        redirect_to second_thanks_recruits_path
      else
        flash[:error] = @recruit.errors.full_messages.to_sentence
        render 'edit'
      end
    end
  
    def import
      cnt = Recruit.import(params[:file])
      redirect_to recruits_url, notice:"#{cnt}件登録されました。"
    end
  
    private
    def recruit_params
      params.require(:recruit).permit(
        :name,
        :age,
        :email,
        :experience,
        :voice_data,
        :year,
        :commodity,
        :hope,
        :period,
        :pc,
        :start,
        :tel,
        :agree_1,
        :agree_2,
        :emergency_name,
        :emergency_relationship,
        :emergency_tel,
        :identification,
        :bank,
        :branch,
        :bank_number,
        :bank_name,
        :status
      )
    end
end
