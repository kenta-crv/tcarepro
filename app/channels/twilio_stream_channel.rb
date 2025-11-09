class TwilioStreamChannel < ApplicationCable::Channel
  def subscribed
    # This channel handles incoming WebSocket connections from Twilio
    # Twilio will send media stream data here
    stream_from "twilio_stream_#{params[:stream_sid]}" if params[:stream_sid].present?
  end

  def unsubscribed
    stop_all_streams
  end

  # Receive data from Twilio's media stream
  def receive(data)
    # Twilio sends JSON messages with different event types
    return unless data.is_a?(Hash)
    
    event_type = data['event']
    
    case event_type
    when 'start'
      handle_stream_start(data)
    when 'media'
      handle_media_data(data)
    when 'stop'
      handle_stream_stop(data)
    else
      Rails.logger.debug "Unknown Twilio event: #{event_type}"
    end
  end

  private

  def handle_stream_start(data)
    stream_sid = data.dig('start', 'streamSid')
    call_sid = data.dig('start', 'callSid')
    
    Rails.logger.info "Twilio stream started: #{stream_sid} for call: #{call_sid}"
    
    # Store stream information
    if call_sid.present?
      call_info = Rails.cache.read("call_stream_#{call_sid}") || {}
      call_info[:stream_sid] = stream_sid
      call_info[:stream_started_at] = Time.current
      Rails.cache.write("call_stream_#{call_sid}", call_info, expires_in: 1.hour)
      
      # Notify monitoring clients that stream has started
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
  end

  def handle_media_data(data)
    # Extract the media payload
    media = data['media']
    return unless media
    
    stream_sid = data['streamSid']
    payload = media['payload'] # Base64 encoded audio (mulaw)
    timestamp = media['timestamp']
    
    # Get the call_sid associated with this stream
    call_sid = find_call_sid_by_stream(stream_sid)
    
    if call_sid.present?
      # Broadcast the audio data to monitoring clients
      CallStreamService.process_media(call_sid, payload)
      
      # Also send to speech-to-text service if available
      if defined?(SpeechToTextService)
        # Decode the base64 payload
        audio_data = Base64.decode64(payload)
        
        # Broadcast to transcript channel
        ActionCable.server.broadcast(
          "call_audio_#{call_sid}",
          { 
            audio: payload,
            timestamp: timestamp
          }
        )
      end
    end
  end

  def handle_stream_stop(data)
    stream_sid = data.dig('stop', 'streamSid')
    call_sid = find_call_sid_by_stream(stream_sid)
    
    Rails.logger.info "Twilio stream stopped: #{stream_sid}"
    
    if call_sid.present?
      # Notify monitoring clients that stream has stopped
      CallStreamService.end_call(call_sid)
      
      # Clean up cache
      Rails.cache.delete("call_stream_#{call_sid}")
    end
  end

  def find_call_sid_by_stream(stream_sid)
    # Search through cached call streams to find the matching call_sid
    # This is a simple implementation; you might want to optimize this
    Rails.cache.instance_variable_get(:@data).each do |key, value|
      if key.start_with?('call_stream_') && value.is_a?(Hash) && value[:stream_sid] == stream_sid
        return key.sub('call_stream_', '')
      end
    end
    nil
  end
end

