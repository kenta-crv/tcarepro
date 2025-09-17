class SendersController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_sender, only: [:show, :edit, :update, :destroy]

  def index
    @senders = Sender.all
    @sender_stats = {}
    
    @senders.each do |sender|
      contact_trackings = ContactTracking.where(sender_id: sender.id)
      
      # 🔥 修正: 全顧客数を正しく計算
      total_customers = Customer.count
      sent_count = contact_trackings.where(status: '送信済').count
      
      # 未送信数を正確に計算
      contacted_customer_ids = contact_trackings.select(:customer_id).distinct.pluck(:customer_id)
      unsent_count = total_customers - contacted_customer_ids.count
      
      # フォーム存在数（contact_urlがあるもの）
      form_exists_count = contact_trackings.where.not(contact_url: [nil, '']).count
      
      # 実送信数（contact_urlがあり、かつ送信済み）
      actual_sent_count = contact_trackings.where(status: '送信済')
                                        .where.not(contact_url: [nil, ''])
                                        .count
      
      # エラー数（真のエラーののみ）
      error_count = contact_trackings.where(status: [
        'CAPTCHA detected - requires manual intervention',
        '自動送信エラー',
        '送信失敗: no_success_indication', 
        '送信失敗: submission_failed'
      ]).count
      
      @sender_stats[sender.id] = {
        total: total_customers,
        unsent: unsent_count,  # 追加
        unsent2: unactual_sent_count,
        sent: sent_count,
        form_exists: form_exists_count,
        actual_sent: actual_sent_count,
        error: error_count,
        send_rate: total_customers > 0 ? (sent_count.to_f / total_customers * 100).round(1) : 0,
        actual_rate: sent_count > 0 ? (actual_sent_count.to_f / sent_count * 100).round(1) : 0
      }
    end
  end

  def show
    @sender = Sender.find(params[:id])
    @form = SenderForm.new(
      sender: @sender,
      year: params[:year]&.to_i || Time.zone.now.year,
      month: params[:month]&.to_i || Time.zone.now.month,
    )
    @data = AutoformResult.where(sender_id: params[:id])
  end

  def new
    @sender = Sender.new
  end

  def edit
  end

  def create
    @sender = Sender.new(sender_params)

    if @sender.save
      redirect_to @sender, notice: 'Sender was successfully created.'
    else
      render :new
    end
  end

  def update
    if @sender.update(sender_params)
      redirect_to @sender, notice: 'Sender was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @sender.destroy
    redirect_to senders_url, notice: 'Sender was successfully destroyed.'
  end

  private

  def set_sender
    @sender = Sender.find(params[:id])
  end

  def sender_params
    params.require(:sender).permit(:user_name, :email, :password, :password_confirmation, :rate_limit, :default_inquiry_id, :url)
  end
end