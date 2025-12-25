require 'sidekiq'
require 'sidekiq/web'
require 'sidekiq-cron'

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end

# Schedule email verification to run every 10 minutes
Sidekiq::Cron::Job.create(
  name: 'Email Verification - every 10 minutes',
  cron: '*/10 * * * *', # Every 10 minutes
  class: 'EmailVerificationWorker'
) unless Sidekiq::Cron::Job.find('Email Verification - every 10 minutes')
