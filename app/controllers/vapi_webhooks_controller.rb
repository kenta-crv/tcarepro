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
    
    # Use VAPI's call ID as the primary identifier if CallSid not available
    # We'll update it later when Twilio CallSid becomes available
    identifier = call_sid.present? ? call_sid : call_id
    
    if identifier.blank?
      Rails.logger.error "No CallSid or CallId provided in VAPI webhook"
      render json: { 
        status: 'error', 
        message: 'CallSid or CallId is required' 
      }, status: 400
      return
    end
    
    Rails.logger.info "Identifier: #{identifier} (CallSid: #{call_sid || 'N/A'}, CallId: #{call_id || 'N/A'})"
    Rails.logger.info "Listen URL: #{listen_url}"
    Rails.logger.info "To Number: #{to_number}"
    
    # Create or update call record (use identifier, will update with real CallSid later)
    call_record = create_or_update_call_record(identifier, to_number, call_id, call_sid)
    
    # Store call info in cache
    call_info = {
      connected_at: Time.current,
      vapi_listen_url: listen_url,
      vapi_control_url: control_url,
      vapi_call_id: call_id,
      twilio_call_sid: call_sid, # Will be nil initially, updated later
      to_number: to_number,
      customer_id: call_record&.customer_id
    }
    
    if call_record
      call_info[:call_id] = call_record.id
    end
    
    # Store with identifier for lookup
    Rails.cache.write("call_stream_#{identifier}", call_info, expires_in: 2.hours)
    
    # Also store mapping if we have both identifiers
    if call_sid.present? && call_id.present?
      Rails.cache.write("vapi_id_to_twilio_sid_#{call_id}", call_sid, expires_in: 2.hours)
      Rails.cache.write("twilio_sid_to_vapi_id_#{call_sid}", call_id, expires_in: 2.hours)
      # Also store with Twilio CallSid for compatibility
      Rails.cache.write("call_stream_#{call_sid}", call_info, expires_in: 2.hours)
    end
    
    # Start WebSocket connection to VAPI (use identifier as call_sid for now)
    begin
      service = VapiWebsocketService.new(call_id || identifier, listen_url, identifier)
      service.start
      
      Rails.logger.info "VAPI WebSocket service started for call #{identifier}"
      
      render json: { 
        status: 'success', 
        message: 'WebSocket connection started',
        call_sid: identifier,
        vapi_call_id: call_id
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
  
  def create_or_update_call_record(identifier, to_number, vapi_call_id, twilio_call_sid)
    # Use the identifier (CallSid if available, otherwise VAPI ID)
    # Try to find existing call by either identifier
    call = Call.find_by(vapi_call_id: twilio_call_sid) if twilio_call_sid.present?
    call ||= Call.find_by(vapi_call_id: identifier)
    
    if call
      # Update existing call
      update_data = { statu: "通話中" }
      if twilio_call_sid.present? && call.vapi_call_id != twilio_call_sid
        update_data[:vapi_call_id] = twilio_call_sid
      end
      call.update(update_data) if call.statu != "通話中" || (twilio_call_sid.present? && call.vapi_call_id != twilio_call_sid)
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
      # Use Twilio CallSid if available, otherwise use VAPI ID
      vapi_id_for_db = twilio_call_sid.present? ? twilio_call_sid : identifier
      call = customer.calls.create(
        statu: "通話中",
        vapi_call_id: vapi_id_for_db, # Use Twilio CallSid if available, otherwise VAPI ID
        comment: "Live monitored call via VAPI"
      )
      Rails.logger.info "Created call record with customer: #{call.id} (vapi_call_id: #{vapi_id_for_db})"
      return call
    else
      # Call model requires customer_id, so we can't create without customer
      # The call will still be monitored via cache, just won't have a DB record
      Rails.logger.warn "No customer found for number: #{to_number}. Call will be monitored via cache only."
      return nil
    end
  end
end

