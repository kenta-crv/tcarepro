class Api::V1::CallsController < ApiController
  def create
    begin
      # Find the customer
      customer = Customer.find(params[:customer_id])
      
      # Create the call record
      call = customer.calls.create!(
        statu: params[:statu] || "自動コール完了",
        recording_url: params[:recording_url],
        recording_duration: params[:recording_duration],
        vapi_call_id: params[:vapi_call_id],
        comment: params[:comment] || "Automated call via Vapi"
      )
      
      render json: { 
        status: 'SUCCESS', 
        call_id: call.id,
        message: 'Call record stored successfully',
        recording_url: call.recording_url
      }
      
    rescue ActiveRecord::RecordNotFound
      render json: { 
        status: 'ERROR', 
        message: 'Customer not found' 
      }, status: 404
      
    rescue ActiveRecord::RecordInvalid => e
      render json: { 
        status: 'ERROR', 
        message: 'Validation failed',
        errors: e.record.errors.full_messages 
      }, status: 422
      
    rescue => e
      render json: { 
        status: 'ERROR', 
        message: 'Internal server error',
        error: e.message 
      }, status: 500
    end
  end
end
