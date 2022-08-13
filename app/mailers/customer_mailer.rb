class CustomerMailer < ActionMailer::Base
  default from: "mail@ri-plus.jp"
  def received_email(customer)
    @customer = customer
    mail to: "mail@ri-plus.jp"
    mail(subject: '資料送付完了') do |format|
      format.text
    end
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
