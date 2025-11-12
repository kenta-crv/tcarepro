class CallStreamChannel < ApplicationCable::Channel
  def subscribed
    # Stream from a unique channel for each call
    stream_from "call_stream_#{params[:call_id]}" if params[:call_id].present?
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    stop_all_streams
  end
end
