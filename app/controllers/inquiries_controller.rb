class InquiriesController < ApplicationController
  before_action :authenticate_sender!, only: [:edit, :new]
    def index
      @inquiries = Inquiry.all
    end

    def show
      @inquiry = Inquiry.find(params[:id])
    end

    def new
      @inquiry = Inquiry.new
    end

    def create
      @inquiry = Inquiry.new(inquiry_params)
      if @inquiry.save
        redirect_to inquiries_path
      else
        render 'new'
      end
    end

    def edit
      @inquiry = Inquiry.find(params[:id])
    end

    def destroy
      @inquiry = Inquiry.find(params[:id])
      @inquiry.destroy
       redirect_to inquiries_path
    end

    def update
      @inquiry = Inquiry.find(params[:id])
      if @inquiry.update(inquiry_params)
        redirect_to inquiries_path
      else
        render 'edit'
      end
    end

    private
    def inquiry_params
      params.require(:inquiry).permit(
        :headline, #案件名
        :from_company, #会社名
        :person, #担当者
        :person_kana, #タントウシャ
        :from_tel, #電話番号
        :from_fax, #FAX番号
        :from_mail, #メールアドレス
        :url, #HP
        :address, #住所
        :title, #件名
        :content #本文
        )
    end
end
