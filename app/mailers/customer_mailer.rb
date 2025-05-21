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
  
  def send_thinreports_data(customer_email, data, pdf_content)
    @data = data  # データを直接使用
    app_count_customers = @data[:app_count_customers]
    attachments['report.pdf'] = pdf_content
    mail(
      from: "info@ri-plus.jp", 
      to: customer_email, 
      subject: '請求書発行のご案内'
    )
  end

  def upload_process_complete(email, message)
    mail(
      to: email,
      from: "info@ri-plus.jp",
      subject: message,
      body: message,
      content_type: "text/plain"
    )
  end
end

