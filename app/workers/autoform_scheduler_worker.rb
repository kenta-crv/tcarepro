require 'open3'
require 'rest-client'

class AutoformSchedulerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 3, queue: 'default', backtrace: true

  # Use host.docker.internal to access Windows host from Docker
  PYTHON_API_URL = "http://python-worker:6400/api/v1/rocketbumb"

  def perform(contact_tracking_id)
    contact_tracking = ContactTracking.find_by(id: contact_tracking_id)
    unless contact_tracking
      Sidekiq.logger.error "AutoformSchedulerWorker: ContactTracking with ID #{contact_tracking_id} not found."
      return
    end

    # Skip if already processed
    if contact_tracking.status == '送信済' || contact_tracking.status == '自動送信エラー'
      Sidekiq.logger.info "AutoformSchedulerWorker: ContactTracking #{contact_tracking_id} already processed with status: #{contact_tracking.status}"
      return
    end

    ContactTracking.transaction do
      begin
        # 送信開始状態の記録
        contact_tracking.update!(
          status: '送信中',
          sending_started_at: Time.current
        )

        # URL自動検索機能 - スキップして直接API呼び出し
        if contact_tracking.contact_url.blank?
          contact_tracking.update!(
            status: '自動送信エラー',
            sending_completed_at: Time.current,
            response_data: 'URLがありません'
          )
          return
        end

        # Always use the associated inquiry
        inquiry = contact_tracking.inquiry
        unless inquiry
          error_message = "No Inquiry associated with this contact tracking."
          Sidekiq.logger.error "AutoformSchedulerWorker: #{error_message}"
          contact_tracking.update!(
            status: '自動送信エラー(データ無)',
            sending_completed_at: Time.current,
            response_data: error_message
          )
          return
        end

        # Send job to Python Flask API
        send_to_python_api(contact_tracking, inquiry)

        # Update status to processing
        contact_tracking.update!(
          status: '処理中',
          sending_completed_at: Time.current,
          response_data: "Job sent to Python API for processing"
        )

        Sidekiq.logger.info "AutoformSchedulerWorker: Successfully sent job #{contact_tracking_id} to Python API"

      rescue RestClient::Exception => e
        Sidekiq.logger.error "AutoformSchedulerWorker: Python API communication failed for CT ID #{contact_tracking_id}: #{e.message}"
        contact_tracking.update!(
          status: '自動送信システムエラー(API通信失敗)',
          sending_completed_at: Time.current,
          response_data: "API Error: #{e.message}"
        )
        
      rescue Timeout::Error => e
        Sidekiq.logger.error "AutoformSchedulerWorker: Python API timeout for CT ID #{contact_tracking_id}"
        contact_tracking.update!(
          status: '自動送信エラー(タイムアウト)',
          sending_completed_at: Time.current,
          response_data: "Timeout after 30 seconds"
        )
        
      rescue StandardError => e
        Sidekiq.logger.error "AutoformSchedulerWorker: Error for CT ID #{contact_tracking_id}: #{e.message}"
        Sidekiq.logger.error e.backtrace.join("\n")
        
        contact_tracking.update!(
          status: '自動送信システムエラー(ワーカー例外)',
          sending_completed_at: Time.current,
          response_data: "Exception: #{e.message}"
        )
      end
    end
  end

  private

  def send_to_python_api(contact_tracking, inquiry)
    payload = {
      worker_id: contact_tracking.worker_id,
      inquiry_id: contact_tracking.inquiry_id,
      contact_url: contact_tracking.contact_url,
      date: contact_tracking.scheduled_date.strftime("%Y-%m-%d %H:%M:%S"),
      reserve_code: contact_tracking.auto_job_code,
      generation_code: "gen_#{contact_tracking.id}",
      company_name: contact_tracking.customer.company,
      customers_code: contact_tracking.customer_id
    }

    # Add inquiry data to payload
    add_inquiry_data_to_payload(payload, inquiry)

    Sidekiq.logger.info "AutoformSchedulerWorker: Sending to Python API: #{payload}"

    response = RestClient::Request.execute(
      method: :post,
      url: PYTHON_API_URL,
      payload: payload.to_json,
      headers: {
        content_type: :json,
        accept: :json
      },
      timeout: 30
    )

    Sidekiq.logger.info "AutoformSchedulerWorker: Python API response: #{response.code} - #{response.body}"
    
    # Check if Python API accepted the job
    unless response.code == 200
      raise RestClient::Exception.new("Python API returned non-200 status: #{response.code}")
    end
    
  rescue RestClient::Exception => e
    Sidekiq.logger.error "AutoformSchedulerWorker: Failed to send to Python API: #{e.message}"
    raise e
  end

  def add_inquiry_data_to_payload(payload, inquiry)
    payload.merge!({
      from_company: inquiry.from_company.to_s,
      person: inquiry.person.to_s,
      person_kana: inquiry.person_kana.to_s,
      from_tel: inquiry.from_tel.to_s,
      from_fax: inquiry.from_fax.to_s,
      from_mail: inquiry.from_mail.to_s,
      address: inquiry.address.to_s,
      title: inquiry.title.to_s,
      content: inquiry.content.to_s,
      url: inquiry.url.to_s
    })
  end
end