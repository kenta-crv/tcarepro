class TwilioMediaController < ApplicationController
  skip_before_action :verify_authenticity_token
  
  def twiml
    # Generate TwiML to instruct Twilio to stream audio to your WebSocket server
    response = Twilio::TwiML::VoiceResponse.new do |r|
      r.say('This call is being monitored and transcribed for quality assurance purposes.')
      r.stream(url: "wss://#{request.host}/twilio-media-stream")
      
      # Forward the call to the destination number
      if params[:To].present?
        r.dial do |d|
          d.number(params[:To])
        end
      end
    end
    
    render xml: response.to_s
  end
  
  # Webhook for call status updates
  def status
    call_sid = params[:CallSid]
    status = params[:CallStatus]
    
    if call_sid.present?
      call = Call.find_by(vapi_call_id: call_sid)
      
      if call && status == "completed"
        # Update call status when completed
        call.update(statu: "通話終了")
      end
    end
    
    head :ok
  end
end
