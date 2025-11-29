class VapiWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false
  
  def receive
    Rails.logger.info "=== VAPI WEBHOOK RECEIVED ==="
    Rails.logger.info "Params: #{params.inspect}"
    
    # VAPI sends monitor URLs in the webhook
    monitor = params[:monitor] || params['monitor'] || {}
    call_sid = params[:callSid] || params[:call_sid] || params[:twilioCallSid] || params[:twilio_call_sid]
    call_id = params[:callId] || params[:call_id] || params[:id]
    to_number = params[:to] || params[:customer]&.dig(:number) || params['customer']&.dig('number')
    
    # Get listen URL from monitor object
    listen_url = monitor[:listenUrl] || monitor['listenUrl'] || monitor[:listen_url] || monitor['listen_url']
    control_url = monitor[:controlUrl] || monitor['controlUrl'] || monitor[:control_url] || monitor['control_url']
    
    if listen_url.blank?
      Rails.logger.error "No listenUrl provided in VAPI webhook"
      render json: { 
        status: 'error', 
        message: 'Monitor listenUrl is required' 
      }, status: 400
      return
    end
    
    if call_sid.blank?
      Rails.logger.error "No CallSid provided in VAPI webhook"
      render json: { 
        status: 'error', 
        message: 'CallSid is required' 
      }, status: 400
      return
    end
    
    Rails.logger.info "CallSid: #{call_sid}"
    Rails.logger.info "CallId: #{call_id}"
    Rails.logger.info "Listen URL: #{listen_url}"
    Rails.logger.info "To Number: #{to_number}"
    
    # Create or update call record
    call_record = create_or_update_call_record(call_sid, to_number, call_id)
    
    # Store call info in cache
    call_info = {
      connected_at: Time.current,
      vapi_listen_url: listen_url,
      vapi_control_url: control_url,
      vapi_call_id: call_id,
      to_number: to_number,
      customer_id: call_record&.customer_id
    }
    
    if call_record
      call_info[:call_id] = call_record.id
    end
    
    Rails.cache.write("call_stream_#{call_sid}", call_info, expires_in: 2.hours)
    
    # Start WebSocket connection to VAPI
    begin
      service = VapiWebsocketService.new(call_id || call_sid, listen_url, call_sid)
      service.start
      
      Rails.logger.info "VAPI WebSocket service started for call #{call_sid}"
      
      render json: { 
        status: 'success', 
        message: 'WebSocket connection started',
        call_sid: call_sid
      }
    rescue => e
      Rails.logger.error "Error starting VAPI WebSocket service: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      render json: { 
        status: 'error', 
        message: "Failed to start WebSocket: #{e.message}" 
      }, status: 500
    end
  end
  
  private
  
  def create_or_update_call_record(call_sid, to_number, vapi_call_id)
    # Try to find existing call
    call = Call.find_by(vapi_call_id: call_sid)
    
    if call
      # Update existing call
      call.update(statu: "通話中") if call.statu != "通話中"
      Rails.logger.info "Updated existing call record: #{call.id}"
      return call
    end
    
    # Try to find customer by phone number
    customer = nil
    if to_number.present?
      # Clean phone number (remove non-digits)
      clean_number = to_number.gsub(/\D/, '')
      
      # Try different search patterns
      customer = Customer.where("REPLACE(REPLACE(REPLACE(REPLACE(tel, '-', ''), ' ', ''), '(', ''), ')', '') LIKE ?", "%#{clean_number[-10..-1]}%").first
      
      if customer.nil? && clean_number.length >= 10
        # Try last 10 digits
        customer = Customer.where("tel LIKE ?", "%#{clean_number[-10..-1]}%").first
      end
    end
    
    if customer
      # Create call with customer
      call = customer.calls.create(
        statu: "通話中",
        vapi_call_id: call_sid,
        comment: "Live monitored call via VAPI"
      )
      Rails.logger.info "Created call record with customer: #{call.id}"
      return call
    else
      # Call model requires customer_id, so we can't create without customer
      # The call will still be monitored via cache, just won't have a DB record
      Rails.logger.warn "No customer found for number: #{to_number}. Call will be monitored via cache only."
      return nil
    end
    
    call
  end
end

