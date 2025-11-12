class Api::V1::CallStreamsController < ApiController
  # No need to skip verify_authenticity_token since ApiController inherits from ActionController::API
  # which doesn't have CSRF protection enabled by default
  
  # This endpoint will receive the Twilio WebSocket connection
  def create
    # Extract call_sid from Twilio's request
    call_sid = params[:call_sid]
    
    if call_sid.blank?
      render json: { status: 'ERROR', message: 'Call SID is required' }, status: 400
      return
    end
    
    # Find or create a call record
    customer_id = params[:customer_id]
    call = nil
    
    if customer_id.present?
      customer = Customer.find_by(id: customer_id)
      if customer
        call = customer.calls.create(
          statu: "通話中", # Call in progress
          vapi_call_id: call_sid,
          comment: "Live call monitoring"
        )
      end
    end
    
    # Store connection info for later use
    Rails.cache.write("call_stream_#{call_sid}", {
      connected_at: Time.current,
      call_id: call&.id,
      customer_id: customer_id
    })
    
    # Return success
    render json: { status: 'SUCCESS', message: 'Stream connection established' }
  end
  
  # This endpoint will receive audio data from Twilio
  def stream
    # This is a WebSocket endpoint, so we'll handle the connection differently
    # The actual implementation will be in the WebSocket channel
    
    # Just return a 200 OK for now
    head :ok
  end
  
  # This endpoint will be called when the call ends
  def complete
    call_sid = params[:call_sid]
    
    if call_sid.present?
      # Get the call info from cache
      call_info = Rails.cache.read("call_stream_#{call_sid}")
      
      if call_info && call_info[:call_id].present?
        call = Call.find_by(id: call_info[:call_id])
        if call
          call.update(
            statu: "通話終了", # Call ended
            recording_duration: params[:duration].to_i,
            recording_url: params[:recording_url]
          )
        end
      end
      
      # Clean up
      Rails.cache.delete("call_stream_#{call_sid}")
    end
    
    render json: { status: 'SUCCESS', message: 'Call completed' }
  end
end
