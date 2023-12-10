class RecruitMailer < ActionMailer::Base
  default from: "recruit@ri-plus.jp"
  def received_email(recruit)
    @recruit = recruit
    mail to: "recruit@ri-plus.jp"
    mail(subject: '音声面接応募がありました') do |format|
      format.text
    end
  end

  def send_email(recruit)
    @recruit = recruit
    mail to: recruit.email
    mail(subject: '音声面接にご応募頂き誠にありがとうございます。') do |format|
      format.text
    end
  end

  def offer_email(recruit)
    @recruit = recruit
    mail to: recruit.email
    mail(subject: '音声面接結果のご案内') do |format|
      format.text
    end
  end

  def reject_email(recruit)
    @recruit = recruit
    @edit_url = edit_recruit_url(@recruit)
    mail to: recruit.email
    mail(subject: '音声面接結果のご案内') do |format|
      format.text
    end
  end

  def second_received_email(recruit)
    @recruit = recruit
    mail to: "recruit@ri-plus.jp"
    mail(subject: '#{recruit.name}さんが契約に同意しました。') do |format|
      format.text
    end
  end

  def second_send_email(recruit)
    @recruit = recruit
    mail to: recruit.email
    mail(subject: '契約に同意いただきありがとうございます。') do |format|
      format.text
    end
  end
end
