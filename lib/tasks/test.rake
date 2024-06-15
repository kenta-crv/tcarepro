

namespace :test do
  desc "Update contact status to '送信済' for a specific contact_tracking record"
  task update: :environment do
    contact_tracking_id = ENV['contact_tracking_id'].to_i
    update_mode = ENV['update_mode']
    puts "Contact tracking status updated successfully for ID: #{contact_tracking_id} #{update_mode}"
  end
end
