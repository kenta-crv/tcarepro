every 1.hour do
    runner "UserMailer.send_batch_emails"
end
  