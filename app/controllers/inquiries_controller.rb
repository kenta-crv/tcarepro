class InquiriesController < ApplicationController
  before_action :authenticate_admin_or_sender!
  before_action :set_sender

  def index
    @inquiries = @sender.inquiries
  end

  def show
    @inquiry = @sender.inquiries.find(params[:id])
  end

  def new
    @inquiry = @sender.inquiries.new
  end

  def create
    @inquiry = @sender.inquiries.new(inquiry_params)
    if @inquiry.save
      unless @sender.default_inquiry
        @sender.default_inquiry = @inquiry
        @sender.save!
      end

      if sender_signed_in?
        redirect_to myself_path
      else
        redirect_to sender_inquiries_path(@sender)
      end
    else
      render 'new'
    end
  end

  def edit
    @inquiry = @sender.inquiries.find(params[:id])
  end

  def destroy
    @inquiry = @sender.inquiries.find(params[:id])
    @inquiry.destroy

    if sender_signed_in?
      redirect_to myself_path
    else
      redirect_to sender_inquiries_path(@sender)
    end
  end

  def update
    @inquiry = @sender.inquiries.find(params[:id])
    if @inquiry.update(inquiry_params)
      redirect_to sender_inquiries_path(@sender)
    else
      render 'edit'
    end
  end

  def default
    inquiry = @sender.inquiries.find(params[:inquiry_id])

    @sender.default_inquiry = inquiry

    @sender.save!

    redirect_to sender_inquiries_path(@sender)
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

  def authenticate_admin_or_sender!
    unless admin_signed_in? || sender_signed_in?
       redirect_to new_sender_session_path, alert: 'error'
    end
  end

  def set_sender
    @sender = current_sender || Sender.find(params[:sender_id])
  end
end
