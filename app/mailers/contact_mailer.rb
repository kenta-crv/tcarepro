class ContactMailer < ActionMailer::Base
  default from: "mail@tcare.pro"
  def received_email(contact)
    @contact = contact
    mail to: "mail@tcare.pro"
    mail(subject: 'TCAREよりお問い合わせがありました') do |format|
      format.text
    end
  end

  def send_email(contact)
    @contact = contact
    mail to: contact.email
    mail(subject: 'TCAREにお問い合わせ頂きありがとうございます') do |format|
      format.text
    end
  end

end
