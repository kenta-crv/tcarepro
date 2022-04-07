require 'contactor'

class OkuriteController < ApplicationController
  before_action :authenticate_worker_or_admin!, except: :callback
  before_action :set_sender, except: :callback
  before_action :set_customers, only: [:index, :preview]

  def index
    @customers = @customers.page(params[:page]).per(30)

    @contact_trackings = @customers.flat_map(&:contact_trackings).select do |contact_tracking|
      contact_tracking.sender_id == @sender.id
    end
  end

  def show
    @customer = Customer.find(params[:id])
  end

  def create
    @sender.send_contact!(
      params[:okurite_id],
      current_worker&.id,
      params[:inquiry_id],
      params[:contact_url],
      params[:status]
    )

    if params[:next_customer_id].present?
      redirect_to sender_okurite_preview_path(
        okurite_id: params[:next_customer_id], 
        q: params[:q]&.permit!
      )
    else
      flash[:notice] = "送信が完了しました"

      redirect_to sender_okurite_index_path(sender_id: sender.id)
    end
  end

  def preview
    @customer = Customer.find(params[:okurite_id])
    @inquiry = Inquiry.first

    @prev_customer = @customers.where("customers.id < ?", @customer.id).last
    @next_customer = @customers.where("customers.id > ?", @customer.id).first
    @contact_tracking = ContactTracking.find_by(
      code: @sender.generate_code(@customer.id),
    )

    contactor = Contactor.new(@inquiry, @sender)

    @contact_url = params['force_google'] ? @customer.google_search_url : @customer.contact_url

    gon.typings = contactor.try_typings(@contact_url, @customer.id)
  end

  def callback
    @contact_tracking = ContactTracking.find_by!(code: params[:t])

    @contact_tracking.callbacked_at = Time.zone.now

    @contact_tracking.save

    redirect_to @contact_tracking.inquiry.url
  end

  private

  def set_sender
    @sender = Sender.find(params[:sender_id])
  end

  def set_customers
    @q = Customer.ransack(params[:q])
    @customers = @q.result.distinct

    if params[:q] && params[:q][:contact_tracking_status_cont_any].select { |c| c.present? }.count > 0
      @customers = @customers.joins(:contact_trackings).where(contact_trackings: { sender_id: @sender.id })
    end
  end

  def authenticate_worker_or_admin!
    unless worker_signed_in? || admin_signed_in?
       redirect_to new_worker_session_path, alert: 'error'
    end
  end
end
