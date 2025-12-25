class Okurite::EmailVerificationController < ApplicationController
  before_action :authenticate_sender!
  layout 'send'

  def index
    # Get email verification statistics
    @total_sent = ContactTracking.where(status: ['送信済', '送信成功']).count
    @verified_count = ContactTracking.where(email_received: true).count
    @waiting_count = ContactTracking.where(status: ['送信済', '送信成功'], email_received: false).count
    
    # Calculate verification rate
    @verification_rate = @total_sent > 0 ? (@verified_count.to_f / @total_sent * 100).round(1) : 0
    
    # Get average time to receive email
    verified_with_duration = ContactTracking.where(email_received: true)
                                            .where.not(email_received_at: nil, sended_at: nil)
    if verified_with_duration.any?
      durations = verified_with_duration.map { |ct| ct.email_receipt_duration }
                                         .compact
                                         .reject { |d| d < 0 }
      @avg_time_minutes = durations.any? ? (durations.sum / durations.count / 60.0).round(1) : 0
    else
      @avg_time_minutes = 0
    end
    
    # Get recent verified emails
    @recent_verified = ContactTracking.where(email_received: true)
                                      .order(email_received_at: :desc)
                                      .limit(10)
                                      .includes(:customer)
    
    # Get submissions waiting for email
    @waiting_submissions = ContactTracking.where(status: ['送信済', '送信成功'], email_received: false)
                                         .order(sended_at: :desc)
                                         .limit(10)
                                         .includes(:customer)
    
    # Get daily verification stats for the last 7 days
    @daily_stats = {}
    6.downto(0) do |i|
      date = i.days.ago.to_date
      day_verified = ContactTracking.where(email_received: true, email_received_at: date.all_day).count
      day_sent = ContactTracking.where(status: ['送信済', '送信成功'], sended_at: date.all_day).count
      
      @daily_stats[date.strftime('%Y-%m-%d')] = {
        verified: day_verified,
        sent: day_sent,
        rate: day_sent > 0 ? (day_verified.to_f / day_sent * 100).round(1) : 0
      }
    end
    
    respond_to do |format|
      format.html
      format.csv do
        send_data generate_csv, filename: "email_verification-#{Time.zone.now.strftime('%Y%m%d%H%M%S')}.csv"
      end
    end
  end

  def trigger_verification
    EmailVerificationWorker.perform_async
    redirect_to sender_sender_okurite_email_verification_path(sender_id: params[:sender_id]), notice: 'メール認証チェックを開始しました。'
  end

  private

  def generate_csv
    require 'csv'
    
    CSV.generate(headers: true, encoding: 'UTF-8') do |csv|
      # Header row
      csv << [
        'ID',
        '企業名',
        '送信日時',
        'メール受信',
        'メール受信日時',
        '受信までの時間(分)',
        'メール送信者',
        'メール件名',
        'ステータス',
        '問い合わせURL'
      ]
      
      # Get all sent submissions
      submissions = ContactTracking.where(status: ['送信済', '送信成功'])
                                  .order(sended_at: :desc)
                                  .includes(:customer)
      
      submissions.each do |tracking|
        receipt_time = tracking.email_receipt_duration ? (tracking.email_receipt_duration / 60.0).round(2) : nil
        
        csv << [
          tracking.id,
          tracking.customer&.company || '',
          tracking.sended_at&.strftime('%Y-%m-%d %H:%M:%S') || '',
          tracking.email_received? ? 'はい' : 'いいえ',
          tracking.email_received_at&.strftime('%Y-%m-%d %H:%M:%S') || '',
          receipt_time || '',
          tracking.email_from || '',
          tracking.email_subject || '',
          tracking.status || '',
          tracking.contact_url || ''
        ]
      end
    end
  end
end

