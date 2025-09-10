require 'date'

class Api::V1::PybotcenterController < ApplicationController
  skip_before_action :verify_authenticity_token

  def success
    Rails.logger.info("pybotcenter_success called with params: #{params}")
    
    generation_code = params[:generation_code]
    inquiry_id = params[:inquiry_id]
    reason = params[:reason]
    session_code = params[:session_code]
    detection_method = params[:detection_method]

    # Find by auto_job_code first, then fall back to other methods
    @data = ContactTracking.find_by(auto_job_code: generation_code)
    
    if @data.nil? && session_code.present?
      # Try to find by session_code if auto_job_code not found
      @data = ContactTracking.where(session_code: session_code)
                            .where(inquiry_id: inquiry_id)
                            .first
    end

    if @data
      @data.update!(
        status: '送信済',
        inquiry_id: inquiry_id,
        response_data: reason,
        detection_method: detection_method,
        sended_at: Time.current,
        session_code: session_code
      )
      Rails.logger.info("ContactTracking #{generation_code} marked as SUCCESS")
    else
      Rails.logger.error("ContactTracking not found for generation_code: #{generation_code}, session_code: #{session_code}")
      # Create a new record if not found (fallback)
      ContactTracking.create!(
        auto_job_code: generation_code,
        status: '送信済',
        inquiry_id: inquiry_id,
        response_data: reason,
        detection_method: detection_method,
        sended_at: Time.current,
        session_code: session_code,
        sender_id: 1, # Default sender
        customer_id: Customer.first.id # Fallback customer
      )
    end

    render status: 200, json: {status: 'success_processed'}
  end

  def failed
    Rails.logger.info("pybotcenter_failed called with params: #{params}")
    
    generation_code = params[:generation_code]
    inquiry_id = params[:inquiry_id]
    reason = params[:reason]
    session_code = params[:session_code]
    detection_method = params[:detection_method]

    # Find by auto_job_code first, then fall back to other methods
    @data = ContactTracking.find_by(auto_job_code: generation_code)
    
    if @data.nil? && session_code.present?
      # Try to find by session_code if auto_job_code not found
      @data = ContactTracking.where(session_code: session_code)
                            .where(inquiry_id: inquiry_id)
                            .first
    end

    if @data
      @data.update!(
        status: '自動送信エラー',
        inquiry_id: inquiry_id,
        response_data: reason,
        detection_method: detection_method,
        session_code: session_code
      )
      Rails.logger.info("ContactTracking #{generation_code} marked as FAILED: #{reason}")
    else
      Rails.logger.error("ContactTracking not found for generation_code: #{generation_code}, session_code: #{session_code}")
      # Create a new record if not found (fallback)
      ContactTracking.create!(
        auto_job_code: generation_code,
        status: '自動送信エラー',
        inquiry_id: inquiry_id,
        response_data: reason,
        detection_method: detection_method,
        session_code: session_code,
        sender_id: 1, # Default sender
        customer_id: Customer.first.id # Fallback customer
      )
    end

    render status: 200, json: {status: 'failed_processed'}
  end

  def autoform_data_register
    Rails.logger.info("Autoform data register called with params: #{params}")
    
    session_code = params[:session_code]
    success_count = params[:success_count].to_i
    failed_count = params[:failed_count].to_i
    total_count = success_count + failed_count
    success_rate = total_count > 0 ? (success_count.to_f / total_count * 100).round(2) : 0

    # Create or update autoform result
    autoform_result = AutoformResult.find_or_initialize_by(session_code: session_code)
    autoform_result.update!(
      success_count: success_count,
      failed_count: failed_count,
      success_rate: success_rate,
      total_count: total_count
    )

    Rails.logger.info("Autoform data registered for session: #{session_code}, success rate: #{success_rate}%")
    
    render status: 200, json: {status: 'success', success_rate: success_rate}
  end

  def notify_post
    Pynotify.create(title:params[:title],message:params[:message],status:params[:status],sended_at:DateTime.now)
    render status: 200, json: {void: "void"}
  end

  def graph_register
    Rails.logger.info("@pybots : グラフを登録します。")
    @contra = ContactTracking.find_by(auto_job_code:params[:generate_code])
    return unless @contra

    AutoformResult.create(
      customer_id: @contra.customer_id,
      sender_id: @contra.sender_id,
      worker_id: @contra.worker_id,
      success_sent: params[:success_sent],
      failed_sent: params[:failed_sent]
    )
    
    render status: 200, json: {status: 'graph_registered'}
  end

  def get_inquiry
    @set = Inquiry.find(params[:id])
    render status: 200, json: {inquiry_data: @set}
  end

  def rocketbumb
    Rails.logger.info("rocketbumb called with params: #{params}")
    
    # Extract parameters from JSON request body
    request_data = JSON.parse(request.body.read)
    
    worker_id = request_data['worker_id']
    inquiry_id = request_data['inquiry_id']
    contact_url = request_data['contact_url']
    scheduled_date = request_data['date']
    reserve_key = request_data['reserve_code']
    generation_key = request_data['generation_code']
    company_name = request_data['company_name']
    customers_code = request_data['customers_code']

    Rails.logger.info("Received rocketbumb request: worker_id=#{worker_id}, inquiry_id=#{inquiry_id}, contact_url=#{contact_url}")

    # Find or create contact tracking record
    contact_tracking = ContactTracking.find_or_initialize_by(
        auto_job_code: generation_key
    )

    # Update the contact tracking record with proper validation
    contact_tracking.assign_attributes(
        worker_id: worker_id,
        inquiry_id: inquiry_id,
        contact_url: contact_url,
        scheduled_date: scheduled_date,
        status: '自動送信予定',
        code: SecureRandom.hex(10),
        auto_job_code: generation_key,
        session_code: reserve_key,
        customer_id: customers_code, # Use customers_code as customer_id
        sender_id: 1 # Default sender ID - FIXED validation issue
    )

    if contact_tracking.save
        Rails.logger.info("ContactTracking created/updated successfully: #{generation_key}")
        render status: 200, json: {code: 200, message: generation_key}
    else
        Rails.logger.error("Failed to save ContactTracking: #{contact_tracking.errors.full_messages}")
        render status: 400, json: {code: 400, message: "Failed to save: #{contact_tracking.errors.full_messages.join(', ')}"}
    end

  rescue JSON::ParserError => e
      Rails.logger.error("JSON parse error in rocketbumb: #{e.message}")
      render status: 400, json: {code: 400, message: "Invalid JSON format"}
  rescue => e
      Rails.logger.error("Error in rocketbumb: #{e.message}")
      render status: 500, json: {code: 500, message: "Internal server error"}
  end
end