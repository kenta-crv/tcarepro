# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever

# Rails.rootを使用するために必要
require File.expand_path(File.dirname(__FILE__) + "/environment")
# cronを実行する環境変数
rails_env = ENV['RAILS_ENV'] || :development
# cronを実行する環境変数をセット
set :environment, rails_env
# cronのログの吐き出し場所
set :output, "#{Rails.root}/log/cron.log"


every 1.hour, at: ['0:00', '1:00', '5:00', '6:00', '7:00', '8:00', '9:00', 
                   '17:00', '18:00', '19:00', '20:00', '21:00', '22:00', '23:00'] do
  command "/bin/bash -l -c 'cd /home/smart/webroot/tcarepro/app && bundle exec rails runner -e development \"WorkerCheckJob.perform_now\"'"
end
