# config/application.rb
# デフォルトはUTC (0:00)

# タイムゾーンをセントラルタイム（CDT -5:00 / CST -6:00)に設定
# config.time_zone = 'Central Time (US & Canada)'

# タイムゾーンを東京(JST +9:00)に設定
# config.time_zone = 'Tokyo'
require_relative 'boot'
require 'csv'
require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Smart
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.active_job.queue_adapter = :sidekiq
    config.load_defaults 5.1
    # config.active_record.default_timezone = :local
    config.generators.template_engine = :slim

        config.time_zone = 'Tokyo'
        config.i18n.load_path +=
            Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}').to_s]
        config.i18n.default_locale = :ja

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Thinreports
    config.autoload_paths += %W(#{config.root}/app/reports)

    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
    address: 'smtp.lolipop.jp',
    domain: 'ri-plus.jp',
    port: 587,
    user_name: 'recruit@ri-plus.jp',
    password: ENV['EMAIL_PASSWORD'],
    authentication: 'plain',
    enable_starttls_auto: true
    }

    Dotenv::Railtie.load
  end
end
