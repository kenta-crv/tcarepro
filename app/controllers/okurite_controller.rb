class OkuriteController < ApplicationController
  before_action :authenticate_sender!, except: :callback

  def index
    @q = Customer.ransack(params[:q])
    @customers = @q.result
    @customers = @customers.where.not(url: nil).page(params[:page]).per(30)
  end

  def show
    customer = Customer.find(params[:id])
    inquiry = Inquiry.first

    @contact_tracking = ContactTracking.find_or_initialize_by(
      code: inquiry.generate_code(customer.id),
    )

    @contact_tracking.attributes = {
      customer: customer,
      inquiry: inquiry,
      contact_url: customer.contact_url,
    }
  end

  def create
    customer = Customer.find(params[:okurite_id])
    inquiry = Inquiry.first

    @contact_tracking = ContactTracking.find_or_initialize_by(
      code: inquiry.generate_code(customer.id),
    )

    @contact_tracking.attributes = {
      customer: customer,
      sender: current_sender,
      worker: current_worker,
      inquiry: inquiry,
      contact_url: customer.contact_url,
      sended_at: Time.zone.now,
    }

    @contact_tracking.save!

    redirect_to okurite_url(@contact_tracking.customer)
  end

  def preview
    customer = Customer.find(params[:okurite_id])
    inquiry = Inquiry.first

    @contact_tracking = ContactTracking.find_or_initialize_by(
      code: inquiry.generate_code(customer.id),
    )

    @contact_tracking.attributes = {
      customer: customer,
      sender: current_sender,
      worker: current_worker,
      inquiry: inquiry,
      contact_url: customer.contact_url,
    }

    gon.typings = @contact_tracking.try_typings
  end

  def callback
    @contact_tracking = ContactTracking.find_by!(code: params[:t])

    @contact_tracking.callbacked_at = Time.zone.now

    @contact_tracking.save

    redirect_to @contact_tracking.inquiry.url
  end
end
