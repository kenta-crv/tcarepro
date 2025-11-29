class CallsMonitoringController < ApplicationController
  before_action :authenticate_admin_or_user!
  
  def index
    # Get all active calls from the database
    db_calls = Call.where(statu: "通話中").map do |call|
      call_info = Rails.cache.read("call_stream_#{call.vapi_call_id}")
      
      next if call_info.nil?
      
      {
        call_sid: call.vapi_call_id,
        customer: Customer.find_by(id: call_info[:customer_id]),
        connected_at: call_info[:connected_at],
        duration: ((Time.current - call_info[:connected_at]) / 60).round(2) # in minutes
      }
    end.compact
    
    # Also get calls from cache that might not have Call records (VAPI calls)
    cache_calls = []
    begin
      # Get all cache keys that start with 'call_stream_'
      cache_data = Rails.cache.instance_variable_get(:@data) || {}
      cache_keys = cache_data.keys.select { |k| k.to_s.start_with?('call_stream_') }
      
      cache_calls = cache_keys.map do |key|
        call_sid = key.to_s.sub('call_stream_', '')
        call_info = Rails.cache.read(key)
        
        next if call_info.nil? || call_info[:connected_at].nil?
        next if Call.exists?(vapi_call_id: call_sid) # Skip if already in DB
        
        {
          call_sid: call_sid,
          customer: call_info[:customer_id] ? Customer.find_by(id: call_info[:customer_id]) : nil,
          connected_at: call_info[:connected_at],
          duration: ((Time.current - call_info[:connected_at]) / 60).round(2),
          to_number: call_info[:to_number]
        }
      end.compact
    rescue => e
      Rails.logger.error "Error getting cache calls: #{e.message}"
    end
    
    @active_calls = (db_calls + cache_calls).uniq { |c| c[:call_sid] }
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
