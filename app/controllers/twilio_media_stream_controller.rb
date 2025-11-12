class TwilioMediaStreamController < ActionController::Base
  skip_before_action :verify_authenticity_token, raise: false
  
  def stream
    # This endpoint is for WebSocket upgrade from Twilio
    # Twilio will connect to this endpoint and upgrade to WebSocket
    # The actual WebSocket handling is done by ActionCable
    
    # Check if this is a WebSocket upgrade request
    if request.headers['Upgrade'] == 'websocket'
      # Let ActionCable handle the WebSocket connection
      # Twilio will connect to /cable endpoint instead
      head :switching_protocols
    else
      # If not a WebSocket request, return method not allowed
      head :method_not_allowed
    end
  end
  
  # Alternative HTTP endpoint for testing
  def http_stream
    # This endpoint handles HTTP-based streaming for testing
    response.headers['Content-Type'] = 'text/event-stream'
    
    # Extract the call SID from the request
    call_sid = params[:call_sid] || request.headers['X-Twilio-CallSid']
    
    if call_sid.blank?
      Rails.logger.error("No CallSid provided in Twilio Media Stream request")
      render json: { error: 'CallSid required' }, status: :bad_request
      return
    end
    
    # Find or create a call record
    call = find_or_create_call(call_sid)
    
    # Create a speech service for this stream if available
    speech_service = nil
    if defined?(SpeechToTextService)
      speech_service = SpeechToTextService.new(call_sid)
      speech_service.start_streaming
    end
    
    # Process incoming media packets
    begin
      # Read JSON data from request body
      request_body = request.body.read
      
      if request_body.present?
        data = JSON.parse(request_body)
        
        # Handle different event types
        case data['event']
        when 'start'
          handle_stream_start(call_sid, data)
        when 'media'
          handle_media_data(call_sid, data, speech_service)
        when 'stop'
          handle_stream_stop(call_sid, data)
        end
      end
      
      render json: { status: 'ok' }
    rescue JSON::ParserError => e
      Rails.logger.error("Invalid JSON in Twilio Media Stream: #{e.message}")
      render json: { error: 'Invalid JSON' }, status: :bad_request
    rescue => e
      Rails.logger.error("Error in Twilio Media Stream: #{e.message}")
      render json: { error: e.message }, status: :internal_server_error
    ensure
      # Clean up resources
      speech_service.stop_streaming if speech_service
    end
  end
  
  private
  
  def handle_stream_start(call_sid, data)
    stream_sid = data.dig('start', 'streamSid')
    
    Rails.logger.info "Stream started: #{stream_sid} for call: #{call_sid}"
    
    # Store stream information
    call_info = Rails.cache.read("call_stream_#{call_sid}") || {}
    call_info[:stream_sid] = stream_sid
    call_info[:stream_started_at] = Time.current
    Rails.cache.write("call_stream_#{call_sid}", call_info, expires_in: 1.hour)
    
    # Broadcast stream started event
    ActionCable.server.broadcast(
      "call_stream_#{call_sid}",
      {
        event: 'stream_started',
        call_sid: call_sid,
        stream_sid: stream_sid,
        timestamp: Time.current.to_f
      }
    )
  end
  
  def handle_media_data(call_sid, data, speech_service)
    media = data['media']
    return unless media
    
    payload = media['payload'] # Base64 encoded audio (mulaw)
    timestamp = media['timestamp']
    
    # Broadcast the audio data to monitoring clients
    CallStreamService.process_media(call_sid, payload)
    
    # Process for transcription if service is available
    if speech_service
      audio_data = Base64.decode64(payload)
      speech_service.process_audio(audio_data)
    end
  end
  
  def handle_stream_stop(call_sid, data)
    stream_sid = data.dig('stop', 'streamSid')
    
    Rails.logger.info "Stream stopped: #{stream_sid}"
    
    # Broadcast stream stopped event
    CallStreamService.end_call(call_sid)
    
    # Clean up cache
    Rails.cache.delete("call_stream_#{call_sid}")
  end
  
  def find_or_create_call(call_sid)
    # Try to find an existing call record
    call = Call.find_by(vapi_call_id: call_sid)
    
    # If no call record exists, create one with minimal information
    unless call
      # We don't have customer info at this point, so create a placeholder
      # This will need to be updated later with correct customer information
      call = Call.create(
        vapi_call_id: call_sid,
        statu: "通話中", # Call in progress
        comment: "Twilio transcribed call"
      )
    end
    
    call
  end
end
