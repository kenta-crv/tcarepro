require 'contactor'

class OkuriteController < ApplicationController
  before_action :authenticate_worker_or_admin!, except: :callback
  before_action :set_sender, except: :callback
  before_action :set_customers, only: [:index, :preview]

  def index
    @customers = @customers.page(params[:page]).per(30)

    @contact_trackings = ContactTracking.latest(@sender.id).where(customer_id: @customers.select(:id))
  end

  def show
    @customer = Customer.find(params[:id])
  end

  def create
    @sender.send_contact!(
      params[:callback_code],
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

    @inquiry = @sender.default_inquiry

    @prev_customer = @customers.where("customers.id < ?", @customer.id).last
    @next_customer = @customers.where("customers.id > ?", @customer.id).first
    @contact_tracking = @sender.contact_trackings.where(customer: @customer).order(created_at: :desc).first

    contactor = Contactor.new(@inquiry, @sender)

    @contact_url = @customer.contact_url

    @callback_code = @sender.generate_code

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

    if params[:statuses]&.map(&:presence)&.compact.present?
      @customers = @customers.last_contact_trackings(@sender.id, params[:statuses])
    end
  end

  def authenticate_worker_or_admin!
    unless worker_signed_in? || admin_signed_in?
       redirect_to new_worker_session_path, alert: 'error'
    end
  end
end
