require 'faye/websocket'
require 'eventmachine'
require 'base64'

class VapiWebsocketService
  def initialize(call_id, listen_url, call_sid)
    @call_id = call_id
    @listen_url = listen_url
    @call_sid = call_sid
    @speech_service = nil
    @websocket = nil
    @running = false
  end
  
  def start
    Rails.logger.info "Starting VAPI WebSocket service for call #{@call_sid}"
    Rails.logger.info "Listen URL: #{@listen_url}"
    
    # Validate listen URL
    unless @listen_url.present? && (@listen_url.start_with?('wss://') || @listen_url.start_with?('ws://'))
      Rails.logger.error "Invalid VAPI listen URL: #{@listen_url}"
      return
    end
    
    # Initialize speech-to-text service
    begin
      @speech_service = SpeechToTextService.new(@call_sid)
      @speech_service.start_streaming
      Rails.logger.info "Speech-to-text service started for call #{@call_sid}"
    rescue => e
      Rails.logger.error "Failed to start speech-to-text service: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
    
    # Store in cache
    Rails.cache.write("vapi_call_#{@call_id}", {
      call_sid: @call_sid,
      listen_url: @listen_url,
      started_at: Time.current,
      service_running: true
    }, expires_in: 2.hours)
    
    # Update call stream cache
    call_info = Rails.cache.read("call_stream_#{@call_sid}") || {}
    call_info[:vapi_listen_url] = @listen_url
    call_info[:vapi_call_id] = @call_id
    call_info[:connected_at] ||= Time.current
    Rails.cache.write("call_stream_#{@call_sid}", call_info, expires_in: 2.hours)
    
    # Connect to VAPI's WebSocket in a background thread
    @running = true
    @websocket_thread = Thread.new do
      Thread.current.abort_on_exception = true
      connect_to_vapi_websocket
    end
    
    # Broadcast connection started
    CallStreamService.start_call(@call_sid, call_info[:customer_id])
    
    Rails.logger.info "VAPI WebSocket thread started for call #{@call_sid}"
  end
  
  def stop
    @running = false
    @speech_service&.stop_streaming
    @websocket&.close if @websocket
    
    Rails.cache.delete("vapi_call_#{@call_id}")
    Rails.logger.info "VAPI WebSocket service stopped for call #{@call_sid}"
  end
  
  private
  
  def connect_to_vapi_websocket
    begin
      Rails.logger.info "Attempting to connect to VAPI WebSocket: #{@listen_url}"
      
      # EventMachine.run blocks, so it's already in a thread from start()
      EM.run do
        begin
          ws = Faye::WebSocket::Client.new(@listen_url)
          @websocket = ws
          
          ws.on :open do |event|
            Rails.logger.info "Connected to VAPI WebSocket for call #{@call_id} (#{@call_sid})"
            
            # Broadcast to monitoring clients
            ActionCable.server.broadcast(
              "call_audio_#{@call_sid}",
              {
                event: 'vapi_websocket_connected',
                call_sid: @call_sid,
                timestamp: Time.current.to_f
              }
            )
            
            ActionCable.server.broadcast(
              "call_stream_#{@call_sid}",
              {
                event: 'vapi_websocket_connected',
                call_sid: @call_sid,
                timestamp: Time.current.to_f
              }
            )
          end
          
          ws.on :message do |event|
            handle_websocket_message(event.data) if @running
          end
          
          ws.on :close do |event|
            Rails.logger.info "VAPI WebSocket closed for call #{@call_id} (#{@call_sid}), code: #{event.code}, reason: #{event.reason}"
            @speech_service&.stop_streaming
            
            ActionCable.server.broadcast(
              "call_stream_#{@call_sid}",
              {
                event: 'vapi_websocket_closed',
                call_sid: @call_sid,
                timestamp: Time.current.to_f
              }
            )
            
            EM.stop if @running == false
          end
          
          ws.on :error do |error|
            Rails.logger.error "VAPI WebSocket error for call #{@call_id} (#{@call_sid}): #{error.message}"
            Rails.logger.error "Error class: #{error.class}"
            Rails.logger.error "Listen URL: #{@listen_url}"
            Rails.logger.error error.backtrace.join("\n") if error.respond_to?(:backtrace)
            
            # Broadcast error to monitoring clients
            ActionCable.server.broadcast(
              "call_stream_#{@call_sid}",
              {
                event: 'vapi_websocket_error',
                call_sid: @call_sid,
                error: error.message,
                timestamp: Time.current.to_f
              }
            )
          end
        rescue => e
          Rails.logger.error "Error creating WebSocket client: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          EM.stop
        end
      end
    rescue => e
      Rails.logger.error "Error in VAPI WebSocket connection: #{e.message}"
      Rails.logger.error "Listen URL: #{@listen_url}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Try to reconnect after a delay
      if @running
        sleep(5)
        Rails.logger.info "Retrying VAPI WebSocket connection..."
        connect_to_vapi_websocket if @running
      end
    end
  end
  
  def handle_websocket_message(data)
    begin
      # Try to parse as JSON first
      if data.is_a?(String) && data.start_with?('{')
        message = JSON.parse(data)
        handle_json_message(message)
      else
        # If not JSON, treat as binary audio data
        handle_audio_data(data)
      end
    rescue JSON::ParserError => e
      # If JSON parsing fails, treat as audio
      handle_audio_data(data)
    rescue => e
      Rails.logger.error "Error handling WebSocket message: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
  
  def handle_json_message(message)
    # Handle different message types from VAPI
    if message['type'] == 'audio' || message['audio']
      audio_data = message['audio'] || message['data']
      
      # Decode if base64
      if audio_data.is_a?(String)
        begin
          audio_bytes = Base64.decode64(audio_data)
          handle_audio_data(audio_bytes)
        rescue => e
          Rails.logger.error "Error decoding base64 audio: #{e.message}"
        end
      else
        handle_audio_data(audio_data)
      end
      
    elsif message['type'] == 'transcript' || message['transcript']
      # VAPI might also send transcripts directly
      transcript = message['transcript'] || message['text']
      is_final = message['is_final'] || message['isFinal'] || false
      
      if transcript.present?
        ActionCable.server.broadcast(
          "call_transcript_#{@call_sid}",
          {
            transcript: transcript,
            is_final: is_final
          }
        )
        
        # Update call record if final
        if is_final
          call = Call.find_by(vapi_call_id: @call_sid)
          if call
            existing_transcript = call.transcript || ""
            call.update(transcript: "#{existing_transcript}\n#{transcript}")
          end
        end
      end
      
    elsif message['type'] == 'status' || message['status']
      # Handle status updates
      status = message['status'] || message['type']
      Rails.logger.info "VAPI status update for call #{@call_sid}: #{status}"
      
    else
      # Log unknown message types for debugging
      Rails.logger.debug "Unknown VAPI message type: #{message['type'] || 'unknown'}"
    end
  end
  
  def handle_audio_data(audio_data)
    return unless audio_data.present?
    
    # Process for transcription
    if @speech_service
      begin
        # Ensure we have binary data
        audio_bytes = if audio_data.is_a?(String)
          audio_data.force_encoding('BINARY')
        else
          audio_data
        end
        
        @speech_service.process_audio(audio_bytes)
      rescue => e
        Rails.logger.error "Error processing audio for transcription: #{e.message}"
      end
    end
    
    # Broadcast to monitoring clients (encode as base64 for consistency with Twilio format)
    begin
      encoded_audio = Base64.encode64(audio_data.is_a?(String) ? audio_data.force_encoding('BINARY') : audio_data.to_s)
      
      # Broadcast to call_audio channel for TwilioMediaChannel subscribers
      ActionCable.server.broadcast(
        "call_audio_#{@call_sid}",
        {
          audio: encoded_audio,
          timestamp: Time.current.to_f
        }
      )
      
      # Also use CallStreamService for compatibility
      CallStreamService.process_media(@call_sid, encoded_audio)
    rescue => e
      Rails.logger.error "Error broadcasting audio: #{e.message}"
    end
  end
end

