class MattersController < ApplicationController
  #before_action :authenticate_worker!, except: [:edit, :new]
  before_action :authenticate_admin!, only: [:edit, :new]
    def index
      @matters = Matter.all
    end

    def show
      @matter = Matter.find(params[:id])
    end

    def new
      @matter = Matter.new
    end

    def create
      @matter = Matter.new(matter_params)
      if @matter.save
        redirect_to matters_path
      else
        render 'new'
      end
    end

    def edit
      @matter = Matter.find(params[:id])
    end

    def destroy
      @matter = Matter.find(params[:id])
      @matter.destroy
       redirect_to matters_path
    end

    def update
      @matter = Matter.find(params[:id])
      if @matter.update(matter_params)
        redirect_to matters_path
      else
        render 'edit'
      end
    end

    private
    def matter_params
      params.require(:matter).permit(
        :title, #タイトル
        :description, #詳細
        :possible, #可能
        :impossible, #不可能
        :information, #送信情報
        :attention #注意
        )
    end
end
