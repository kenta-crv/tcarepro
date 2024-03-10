class RecruitMailer < ActionMailer::Base
  default from: "recruit@ri-plus.jp"

  def received_email(recruit)
    @recruit = recruit
    mail(to: "recruit@ri-plus.jp", subject: '音声面接応募がありました')
  end

  def send_email(recruit)
    @recruit = recruit
    mail(to: recruit.email, subject: '音声面接にご応募頂き誠にありがとうございます。')
  end

  def offer_email(recruit)
    @recruit = recruit
    @edit_url = edit_recruit_url(@recruit)
    mail(to: recruit.email, subject: '音声面接結果のご案内')
  end

  def reject_email(recruit)
    @recruit = recruit
    mail(to: recruit.email, subject: '音声面接結果のご案内')
  end

  def second_received_email(recruit)
    @recruit = recruit
    mail(to: "recruit@ri-plus.jp", subject: "#{@recruit.name}さんが契約に同意しました。")
  end

  def second_send_email(recruit)
    @recruit = recruit
    mail(to: recruit.email, subject: '契約に同意いただきありがとうございます。')
  end
end