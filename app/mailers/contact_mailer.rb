class ContactMailer < ActionMailer::Base
  default from: "送信元アドレス"
  default to: "info@comicomi.cc"

  def received_email(contact)
    @contact = contact
    mail(:subject => 'お問い合わせを承りました')
  end
end
