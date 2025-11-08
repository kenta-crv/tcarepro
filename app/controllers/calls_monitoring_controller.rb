class CallsMonitoringController < ApplicationController
  before_action :authenticate_admin_or_user!
  
  def index
    # Get all active calls
    @active_calls = Rails.cache.read_multi(Rails.cache.keys("call_stream_*")).map do |key, value|
      call_sid = key.gsub("call_stream_", "")
      customer = Customer.find_by(id: value[:customer_id]) if value[:customer_id].present?
      
      {
        call_sid: call_sid,
        customer: customer,
        connected_at: value[:connected_at],
        duration: ((Time.current - value[:connected_at]) / 60).round(2) # in minutes
      }
    end
  end
  
  def show
    @call_sid = params[:id]
    @call_info = Rails.cache.read("call_stream_#{@call_sid}")
    
    if @call_info.nil?
      redirect_to calls_monitoring_index_path, alert: "Call not found or no longer active"
      return
    end
    
    @customer = Customer.find_by(id: @call_info[:customer_id]) if @call_info[:customer_id].present?
  end
  
  private
  
  def authenticate_admin_or_user!
    authenticate_admin! || authenticate_user!
  end
end
