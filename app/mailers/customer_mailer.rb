class CustomerMailer < ActionMailer::Base
  default from: "info@comicomi.cc"
  def received_email(customer)
    @customer = customer
    mail to: "info@comicomi.cc"
    mail(subject: 'comicomi参画依頼メールを送信しました。') do |format|
      format.text
    end
  end

  def send_email(customer)
    @customer = customer
    mail to: customer.mail
    mail(subject: '【人材会社専門一括見積りサイトComicomi】参画登録依頼について') do |format|
      format.text
    end
  end
end
