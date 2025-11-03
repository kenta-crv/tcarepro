class CallStreamService
  def self.process_media(call_sid, media_chunk)
    # Broadcast the media chunk to the appropriate channel
    ActionCable.server.broadcast(
      "call_stream_#{call_sid}",
      { 
        chunk: Base64.encode64(media_chunk),
        timestamp: Time.current.to_f
      }
    )
  end
  
  def self.start_call(call_sid, customer_id)
    # Create a record of the call starting
    ActionCable.server.broadcast(
      "call_stream_#{call_sid}",
      {
        event: 'call_started',
        call_sid: call_sid,
        customer_id: customer_id,
        timestamp: Time.current.to_f
      }
    )
  end
  
  def self.end_call(call_sid)
    # Create a record of the call ending
    ActionCable.server.broadcast(
      "call_stream_#{call_sid}",
      {
        event: 'call_ended',
        call_sid: call_sid,
        timestamp: Time.current.to_f
      }
    )
  end
end
