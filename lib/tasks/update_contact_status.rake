namespace :update_contact_status do
  desc "Update contact status to '送信済' for a specific contact_tracking record"
  task update: :environment do
    # コマンドライン引数からIDを取得
    contact_tracking_id = ENV['contact_tracking_id'].to_i
    updateMode= ENV['update_mode']
    puts "Contact Tracking ID: #{contact_tracking_id}"
    puts " ### " + updateMode
    #contact_tracking_id=214589
    # IDに対応するcontact_trackingレコードを取得して、statusを更新する
    contact_tracking = ContactTracking.find_by(id: contact_tracking_id)
    if contact_tracking
      current_time = Time.current
      if updateMode=="1"
        contact_tracking.update(status: "送信済",  sended_at: current_time)
      else
        contact_tracking.update(status:"送信不可",  sended_at: current_time)
      end
      puts "Contact tracking status updated successfully for ID: #{contact_tracking_id}"
    else
      puts "Contact tracking record not found for ID: #{contact_tracking_id}"
    end
  end
end
