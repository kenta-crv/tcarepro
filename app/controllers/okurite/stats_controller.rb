class Okurite::StatsController < ApplicationController
  before_action :authenticate_sender!
  layout 'sender'

  def index
    # Get success count
    @success_count = ContactTracking.where(status: '送信済').count
    @total_count = ContactTracking.where(status: ['送信済', '送信エラー', '自動送信エラー']).count
    
    # Get recent submissions
    @recent_submissions = ContactTracking.order(created_at: :desc).limit(10).includes(:customer)
    
    # Get daily stats for the chart
    @daily_stats = {}
    
    # Get data for the last 7 days
    6.downto(0) do |i|
      date = i.days.ago.to_date
      day_success = ContactTracking.where(status: '送信済', created_at: date.all_day).count
      day_total = ContactTracking.where(status: ['送信済', '送信エラー', '自動送信エラー'], created_at: date.all_day).count
      
      @daily_stats[date.strftime('%Y-%m-%d')] = {
        success: day_success,
        total: day_total
      }
    end
    
    respond_to do |format|
      format.html # This will render app/views/okurite/stats/index.html.slim
    end
  end
end