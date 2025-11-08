class TwilioMediaChannel < ApplicationCable::Channel
  def subscribed
    if params[:call_sid].present?
      # Stream for audio data
      stream_from "call_audio_#{params[:call_sid]}"
      
      # Stream for transcript data
      stream_from "call_transcript_#{params[:call_sid]}"
      
      # Create a speech service for this connection
      @speech_service = SpeechToTextService.new(params[:call_sid])
      @speech_service.start_streaming
    end
  end
  
  def unsubscribed
    # Clean up resources when client disconnects
    if @speech_service
      @speech_service.stop_streaming
      @speech_service = nil
    end
    
    stop_all_streams
  end
  
  # Handle incoming audio data from the client
  def receive(data)
    if @speech_service && data['audio'].present?
      # Process the audio chunk for transcription
      @speech_service.process_audio(data['audio'])
    end
  end
end
