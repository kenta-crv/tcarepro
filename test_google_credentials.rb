#!/usr/bin/env ruby
# Test script to verify Google Cloud Speech-to-Text credentials are set up correctly

require 'json'

puts "=" * 60
puts "Google Cloud Speech-to-Text Credentials Test"
puts "=" * 60
puts

# Check if environment variable is set
env_var = ENV['GOOGLE_APPLICATION_CREDENTIALS']
puts "1. Checking GOOGLE_APPLICATION_CREDENTIALS environment variable..."
if env_var
  puts "   ✅ Environment variable is set: #{env_var}"
else
  puts "   ❌ Environment variable is NOT set"
  puts "   Please add to your .env file:"
  puts '   GOOGLE_APPLICATION_CREDENTIALS="config/credentials/google-speech-credentials.json"'
  exit 1
end

# Check if file exists
puts "\n2. Checking if credentials file exists..."
file_path = File.expand_path(env_var, Dir.pwd)
if File.exist?(file_path)
  puts "   ✅ Credentials file found: #{file_path}"
else
  puts "   ❌ Credentials file NOT found at: #{file_path}"
  exit 1
end

# Check if file is valid JSON
puts "\n3. Checking if credentials file is valid JSON..."
begin
  credentials = JSON.parse(File.read(file_path))
  puts "   ✅ Valid JSON file"
rescue JSON::ParserError => e
  puts "   ❌ Invalid JSON: #{e.message}"
  exit 1
end

# Check required fields
puts "\n4. Checking required credential fields..."
required_fields = ['type', 'project_id', 'private_key', 'client_email']
missing_fields = required_fields - credentials.keys

if missing_fields.empty?
  puts "   ✅ All required fields present"
  puts "   - Project ID: #{credentials['project_id']}"
  puts "   - Client Email: #{credentials['client_email']}"
else
  puts "   ❌ Missing fields: #{missing_fields.join(', ')}"
  exit 1
end

# Try to load the Google Cloud Speech gem
puts "\n5. Checking if google-cloud-speech gem is installed..."
begin
  require 'google/cloud/speech'
  puts "   ✅ google-cloud-speech gem is installed"
rescue LoadError
  puts "   ❌ google-cloud-speech gem is NOT installed"
  puts "   Run: bundle install"
  exit 1
end

puts "\n" + "=" * 60
puts "✅ ALL CHECKS PASSED!"
puts "=" * 60
puts "\nYour Google Cloud Speech-to-Text credentials are properly configured."
puts "You can now use live transcription in your call monitoring system."
puts

