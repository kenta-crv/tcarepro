namespace :update_contact_status do
  desc "Update contact status to '送信済' for a specific contact_tracking record"
  task update: :environment do
    # コマンドライン引数からIDを取得
    contact_tracking_id = ARGV[0].to_i
    argument = ARGV[0]

    # 正規表現を使って ID を抽出する
    match = argument.match(/\[(\d+)\]/)
    if match
      contact_tracking_id = match[1].to_i
      puts "Contact Tracking ID: #{contact_tracking_id}"
    else
      puts "Invalid argument format"
    end
    puts " Update Parameter: #{ARGV[1]}"
    updateMode=ARGV[1]
    #contact_tracking_id=214589
    # IDに対応するcontact_trackingレコードを取得して、statusを更新する
    contact_tracking = ContactTracking.find_by(id: contact_tracking_id)
    if contact_tracking
      if updateMode=="1"
        contact_tracking.update(status: "送信済", , sended_at: current_time)
      else
        contact_tracking.update(status:"送信不可")
      end
      puts "Contact tracking status updated successfully for ID: #{contact_tracking_id}"
    else
      puts "Contact tracking record not found for ID: #{contact_tracking_id}"
    end
  end
end
