class TwilioMediaStreamController < ActionController::Base
  include ActionController::Live
  skip_before_action :verify_authenticity_token, raise: false
  
  def stream
    # This endpoint handles the WebSocket connection from Twilio
    response.headers['Content-Type'] = 'text/event-stream'
    
    # Extract the call SID from the request
    call_sid = request.headers['X-Twilio-CallSid']
    
    if call_sid.blank?
      Rails.logger.error("No CallSid provided in Twilio Media Stream request")
      response.stream.close
      return
    end
    
    # Find or create a call record
    call = find_or_create_call(call_sid)
    
    # Create a speech service for this stream
    speech_service = SpeechToTextService.new(call_sid)
    speech_service.start_streaming
    
    # Process incoming media packets
    begin
      # Keep the connection open
      while true
        # Read binary data from the request
        chunk = request.body.read(1024)
        break if chunk.nil? || chunk.empty?
        
        # Process the audio chunk
        speech_service.process_audio(chunk)
        
        # Also broadcast the raw audio to any listening clients
        ActionCable.server.broadcast(
          "call_audio_#{call_sid}",
          { audio: Base64.encode64(chunk) }
        )
      end
    rescue IOError, ActionController::Live::ClientDisconnected => e
      Rails.logger.info("Client disconnected: #{e.message}")
    rescue => e
      Rails.logger.error("Error in Twilio Media Stream: #{e.message}")
    ensure
      # Clean up resources
      speech_service.stop_streaming if speech_service
      response.stream.close
    end
  end
  
  private
  
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
