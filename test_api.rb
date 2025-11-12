# Test script for the calls API endpoint
require 'net/http'
require 'json'
require 'optparse'

# Parse command line options
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby test_api.rb [options]"

  opts.on("-m", "--mode MODE", "Test mode (call or stream)") do |m|
    options[:mode] = m
  end

  opts.on("-c", "--customer_id ID", "Customer ID") do |c|
    options[:customer_id] = c
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

# Default to call mode if not specified
options[:mode] ||= 'call'
options[:customer_id] ||= '10847'

if options[:mode] == 'call'
  # Test regular call API
  test_data = {
    customer_id: options[:customer_id],
    recording_url: "https://storage.vapi.ai/test-recording.wav",
    recording_duration: 120,
    vapi_call_id: "call_#{Time.now.to_i}",
    comment: "Test automated call"
  }

  # Make the request
  uri = URI('https://tcare.pro/api/v1/calls')
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE  # For testing only
  request = Net::HTTP::Post.new(uri)
  request['Content-Type'] = 'application/json'
  request.body = test_data.to_json

  response = http.request(request)

  puts "Status: #{response.code}"
  puts "Response: #{response.body}"
elsif options[:mode] == 'stream'
  # Test call streaming API
  call_sid = "call_#{Time.now.to_i}"
  
  # 1. Start the stream
  start_data = {
    call_sid: call_sid,
    customer_id: options[:customer_id]
  }

  uri = URI('https://tcare.pro/api/v1/call_streams')
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE  # For testing only
  request = Net::HTTP::Post.new(uri)
  request['Content-Type'] = 'application/json'
  request.body = start_data.to_json

  response = http.request(request)

  puts "Stream Start Status: #{response.code}"
  puts "Stream Start Response: #{response.body}"

  # 2. Simulate streaming for 30 seconds
  puts "Simulating call for 30 seconds..."
  30.times do |i|
    sleep 1
    print "."
    STDOUT.flush
  end
  puts "\nCall simulation complete."

  # 3. End the stream
  complete_data = {
    call_sid: call_sid,
    duration: 30,
    recording_url: "https://storage.vapi.ai/test-recording-#{call_sid}.wav"
  }

  uri = URI('https://tcare.pro/api/v1/call_streams/complete')
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE  # For testing only
  request = Net::HTTP::Post.new(uri)
  request['Content-Type'] = 'application/json'
  request.body = complete_data.to_json

  response = http.request(request)

  puts "Stream Complete Status: #{response.code}"
  puts "Stream Complete Response: #{response.body}"
else
  puts "Invalid mode: #{options[:mode]}"
  puts "Valid modes are: call, stream"
  exit 1
end
