class CustomerMailer < ActionMailer::Base
  default from: "mail@ri-plus.jp"
  def received_email(customer)
    @customer = customer
    mail to: "mail@ri-plus.jp"
    mail(subject: '資料送付完了') do |format|
      format.text
    end
  end

  def teleapo_send_email(customer, email_params)
    @customer = customer
    @body = email_params[:body]
    mail(to: email_params[:mail], from: "h6135197@gmail.com", bcc: "reply@ri-plus.jp", subject: '日程調整のご案内')
  end

  def send_email(customer)
    @customer = customer
    mail to: customer.mail
    mail(subject: '【アポ匠】資料送付のご案内') do |format|
      format.text
    end
  end

  def direct_mail(customer, url, user)
    @customer = customer
    @url = url
    @user = user
    mail to: customer.mail
    mail(subject: '【アポ匠】資料送付のご案内') do |format|
      format.text
    end
  end
end
