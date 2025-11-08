source 'http://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end



# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 5.1.6'
# Use sqlite3 as the database for Active Record
gem 'sqlite3', '< 1.7'
#gem 'pg'
# Use Puma as the app server
gem 'puma', '~> 4.3'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'therubyracer', platforms: :ruby

# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '~> 4.2'
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '~> 5'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.5'
# Use Redis adapter to run Action Cable in production
gem 'redis', '~> 4.0'
# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'
gem 'gon'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

gem 'selenium-webdriver'
gem 'googleauth'
gem 'jwt'
gem 'rack-cors', require: 'rack/cors'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  # Adds support for Capybara system testing and selenium driver
  gem 'capybara', '~> 2.13'
  # Windows file watching optimization
  gem 'wdm', '>= 0.1.0' if Gem.win_platform?
  # gem 'bullet'
  # gem 'rails-erd'
  # gem 'rack-mini-profiler'
  # gem 'flamegraph'
end

group :development do
  # Access an IRB console on exception pages or by using <%= console %> anywhere in the code.
  gem 'web-console', '>= 3.3.0'
  gem 'listen', '>= 3.0.5', '< 3.2'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
  gem 'rubocop', require: false
  gem 'rubocop-rails', require: false
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

gem 'bootstrap', '~> 4.0.0'
gem 'jquery-rails'

gem 'devise'

gem 'meta-tags'

# Thinreports
gem 'thinreports'

gem 'slim-rails'
# gem 'redis'
# gem 'redis-rails'
gem 'pry-rails'

# gem 'bootstrap-sass', '~> 3.0.0'

gem 'carrierwave'

#add by takigawa
gem 'annotate'
gem 'simple_enum'


#gem 'will_paginate'

gem 'haml-rails'

gem 'ransack'


gem 'faker'
gem 'roo'

# JS / Select2を使えるようにする
gem 'select2-rails'

# cron
gem 'whenever', require: false


gem 'jp_prefecture'

gem 'kaminari-bootstrap', '~> 3.0.1'

gem 'sitemap_generator'

gem 'lograge'

gem 'open_uri_redirections'

gem 'active_hash'
#グラフツール
gem 'chartkick'

gem 'httparty'

gem 'audiojs-rails'

gem 'rails_autolink'

gem 'rails-html-sanitizer', '1.4.3'
gem 'dotenv-rails', groups: [:development, :test, :production]
gem 'sidekiq', '~> 5.2'
gem 'sidekiq-cron'

gem 'open3'

gem 'net-imap', '~>0.3.9'

# Twilio for call handling
gem 'twilio-ruby'

# Google Cloud Speech for transcription
gem 'nokogiri', '1.15.7'
gem 'google-protobuf', '3.25.8'
gem 'grpc', '1.65.2'
gem 'google-cloud-speech'