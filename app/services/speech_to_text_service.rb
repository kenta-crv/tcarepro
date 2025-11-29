require "google/cloud/speech"

class SpeechToTextService
  # API key should be loaded from environment variables, not hardcoded
  # See config/initializers/google_cloud_speech.rb
  
  def initialize(call_sid)
    @call_sid = call_sid
    @speech_client = Google::Cloud::Speech.speech
    @streaming_config = {
      config: {
        encoding: :MULAW,
        sample_rate_hertz: 8000,
        language_code: "en-US",
        enable_automatic_punctuation: true,
        use_enhanced: true,
        model: "phone_call"
      },
      interim_results: true
    }
    @transcript_buffer = ""
  end
  
  def start_streaming
    @streaming_recognizer = @speech_client.streaming_recognize(@streaming_config)
    
    # Handle results in a separate thread
    @results_thread = Thread.new do
      @streaming_recognizer.on_result do |results|
        process_results(results)
      end
    end
  end
  
  def process_audio(audio_chunk)
    return unless @streaming_recognizer
    
    begin
      # Write the audio chunk to the recognizer
      @streaming_recognizer.write(audio_chunk)
    rescue => e
      Rails.logger.error("Error processing audio: #{e.message}")
    end
  end
  
  def process_results(results)
    return if results.empty?
    
    results.each do |result|
      transcript = result.alternatives.first.transcript
      
      # Broadcast the transcript to the channel
      ActionCable.server.broadcast(
        "call_transcript_#{@call_sid}",
        { 
          transcript: transcript, 
          is_final: result.is_final 
        }
      )
      
      # Store final results in the database
      if result.is_final
        @transcript_buffer += transcript + "\n"
        
        # Update the call record with the latest transcript
        call = Call.find_by(vapi_call_id: @call_sid)
        if call
          call.update(transcript: @transcript_buffer)
        end
      end
    end
  end
  
  def stop_streaming
    return unless @streaming_recognizer
    
    begin
      # streaming_recognize returns an Enumerator, not an object with a stop method
      # We just need to stop writing to it and let it finish naturally
      # The thread will exit when the enumerator finishes
      @results_thread&.exit
    rescue => e
      Rails.logger.error("Error stopping streaming: #{e.message}")
    ensure
      @streaming_recognizer = nil
      @results_thread = nil
    end
  end
end
