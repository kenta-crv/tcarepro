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
    mail(to: email_params[:mail], from: "info@j-work.jp", subject: '※資料送付【0円採用】国内転職外国人紹介『J Work』')
  end

  def teleapo_reply_email(customer, email_params)
    @customer = customer
    mail(to: "info@j-work.jp", from: "info@j-work.jp", subject: 'アポイント先に資料が送付されました')
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

  def clicked_notice(customer)
    @customer = customer
    mail(
      to: "info@j-work.jp", # 管理者メールアドレス
      from: "info@j-work.jp", # 管理者メールアドレス
      subject: "#{@customer.company}が資料リンクにアクセスしました"
    )
  end
end

