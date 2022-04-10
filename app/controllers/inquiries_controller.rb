class InquiriesController < ApplicationController
  before_action :authenticate_sender!

  def index
    @inquiries = current_sender.inquiries
  end

  def show
    @inquiry = current_sender.inquiries.find(params[:id])
  end

  def new
    @inquiry = current_sender.inquiries.new
  end

  def create
    @inquiry = current_sender.inquiries.new(inquiry_params)
    if @inquiry.save
      unless current_sender.default_inquiry
        current_sender.default_inquiry = @inquiry
        current_sender.save!
      end

      if sender_signed_in?
        redirect_to myself_path
      else
        fail 'TOOD'
      end
    else
      render 'new'
    end
  end

  def edit
    @inquiry = current_sender.inquiries.find(params[:id])
  end

  def destroy
    @inquiry = current_sender.inquiries.find(params[:id])
    @inquiry.destroy
      redirect_to inquiries_path
  end

  def update
    @inquiry = current_sender.inquiries.find(params[:id])
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
