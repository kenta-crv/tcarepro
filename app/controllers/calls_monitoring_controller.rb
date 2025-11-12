class CallsMonitoringController < ApplicationController
  before_action :authenticate_admin_or_user!
  
  def index
    # Get all active calls from the database instead of cache
    @active_calls = Call.where(statu: "通話中").map do |call|
      call_info = Rails.cache.read("call_stream_#{call.vapi_call_id}")
      
      next if call_info.nil?
      
      {
        call_sid: call.vapi_call_id,
        customer: Customer.find_by(id: call_info[:customer_id]),
        connected_at: call_info[:connected_at],
        duration: ((Time.current - call_info[:connected_at]) / 60).round(2) # in minutes
      }
    end.compact
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
