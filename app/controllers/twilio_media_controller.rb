class TwilioMediaController < ActionController::Base
  skip_before_action :verify_authenticity_token, raise: false
  
  def twiml
    # Generate TwiML to instruct Twilio to stream audio to your WebSocket server
    call_sid = params[:CallSid]
    customer_id = params[:customer_id] || params[:CustomerId]
    
    # Store call information
    if call_sid.present?
      Rails.cache.write("call_stream_#{call_sid}", {
        connected_at: Time.current,
        customer_id: customer_id
      }, expires_in: 1.hour)
      
      # Create call record if customer_id is provided
      if customer_id.present?
        customer = Customer.find_by(id: customer_id)
        if customer
          call = customer.calls.create(
            statu: "通話中",
            vapi_call_id: call_sid,
            comment: "Live monitored call"
          )
          
          # Update cache with call_id
          call_info = Rails.cache.read("call_stream_#{call_sid}")
          call_info[:call_id] = call.id
          Rails.cache.write("call_stream_#{call_sid}", call_info, expires_in: 1.hour)
        end
      end
      
      # Broadcast call started event
      CallStreamService.start_call(call_sid, customer_id)
    end
    
    # Generate TwiML response
    response = Twilio::TwiML::VoiceResponse.new do |r|
      r.say(message: 'This call is being monitored and transcribed for quality assurance purposes.', language: 'en-US')
      
      # Stream audio to our WebSocket endpoint
      # Use the cable endpoint for ActionCable WebSocket connections
      r.start.stream(url: "wss://#{request.host}/cable")
      
      # Forward the call to the destination number
      destination = params[:To] || params[:destination]
      if destination.present?
        r.dial(number: destination)
      else
        r.say(message: 'No destination number provided. Please try again.', language: 'en-US')
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
