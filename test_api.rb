# Test script for the calls API endpoint
require 'net/http'
require 'json'

# Test data
test_data = {
  customer_id: 10847,
  recording_url: "https://storage.vapi.ai/test-recording.wav",
  recording_duration: 120,
  vapi_call_id: "call_1234567890",
  comment: "Test automated call"
}

# Make the request
uri = URI('http://localhost:3000/api/v1/calls')
http = Net::HTTP.new(uri.host, uri.port)
request = Net::HTTP::Post.new(uri)
request['Content-Type'] = 'application/json'
request.body = test_data.to_json

response = http.request(request)

puts "Status: #{response.code}"
puts "Response: #{response.body}"
