class CustomerMailer < ActionMailer::Base
  default from: "mail@ri-plus.jp"
  def received_email(customer)
    @customer = customer
    mail to: "mail@ri-plus.jp"
    mail(subject: '資料送付完了') do |format|
      format.text
    end
  end

  def teleapo_send_email(customer, current_user)
    @customer = customer
    @user = current_user 
    mail(to: customer.mail, from: "info@j-work.jp", subject: '【0円採用 J Work】資料・オンライン商談URLのご案内')
  end

  def teleapo_reply_email(customer, current_user)
    @customer = customer
    @user = current_user 
    mail(to: "info@j-work.jp", from: "info@j-work.jp", subject: "【#{@customer.company}】#{@customer.next_date.strftime('%-m月%-d日-%H時%-M分')}")
  end

  def document_send_email(customer, current_user)
    @customer = customer
    @user = current_user 
    mail(to: customer.mail, from: "info@j-work.jp", subject: '【0円採用 J Work】資料送付のご案内')
  end

  def document_reply_email(customer, current_user)
    @customer = customer
    @user = current_user 
    mail(to: "info@j-work.jp", from: "info@j-work.jp", subject: "【#{@customer.company}】へ資料送付が行われました")
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

