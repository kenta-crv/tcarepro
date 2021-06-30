class SkillsheetsController < ApplicationController
  before_action :authenticate_admin!, only: [:edit, :new]
    def index
      @skillsheets = Skillsheet.all
    end

    def show
      @skillsheet = Skillsheet.find(params[:id])
    end

    def new
      @skillsheet = Skillsheet.new
    end

    def create
      @skillsheet = Skillsheet.new(skillsheet_params)
      if @skillsheet.save
        redirect_to skillsheets_path
      else
        render 'new'
      end
    end

    def edit
      @skillsheet = Skillsheet.find(params[:id])
    end

    def destroy
      @skillsheet = Skillsheet.find(params[:id])
      @skillsheet.destroy
       redirect_to skillsheets_path
    end

    def update
      @skillsheet = Skillsheet.find(params[:id])
      if @skillsheet.update(skillsheet_params)
        redirect_to skillsheets_path
      else
        render 'edit'
      end
    end

    private
    def skillsheet_params
      params.require(:skillsheet).permit(
        :name,
        :tel,
        :mail,
        :address,
        :age,
        :start,
        :experience,
        :history,
        :title
        )
    end
end
