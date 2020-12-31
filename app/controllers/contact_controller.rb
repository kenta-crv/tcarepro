class ContactController < ApplicationController
  def index
    @contact = Contact.new
    render :action => 'index'
  end

  def confirm
    @contact = Contact.new(contact_params)
    if @contact.valid?
      render :action =>  'confirm'
    else
      render :action => 'index'
    end
  end

  def thanks
    @contact = Contact.new(contact_params)
    @contact.save
    ContactMailer.received_email(@contact).deliver
    ContactMailer.send_email(@contact).deliver
  end

  private
  def contact_params
    params.require(:contact).permit(
    :company,
    :name,
    :tel,
    :address,
    :email,
    :subject,
    :message
    )
  end
end
