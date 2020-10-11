class CustomerMailerPreview < ActionMailer::Preview
  def customer
     customer =Customer.new(name: "侍 太郎", message: "問い合わせメッセージ")
     customerMailer.send_mail(customer)
   end
end
