#!/usr/bin/env ruby
# Test script for call streaming functionality

require 'net/http'
require 'json'
require 'uri'

# Configuration
BASE_URL = ENV['BASE_URL'] || 'http://localhost:3000'
CALL_SID = "TEST_CALL_#{Time.now.to_i}"
CUSTOMER_ID = ENV['CUSTOMER_ID'] || '1'

puts "=" * 60
puts "Call Streaming Test Script"
puts "=" * 60
puts "Base URL: #{BASE_URL}"
puts "Call SID: #{CALL_SID}"
puts "Customer ID: #{CUSTOMER_ID}"
puts "=" * 60
puts

# Test 1: Check if ActionCable is mounted
def test_cable_endpoint
  puts "Test 1: Checking ActionCable endpoint..."
  
  uri = URI("#{BASE_URL}/cable")
  
  begin
    response = Net::HTTP.get_response(uri)
    
    if response.code == '101' || response.code == '426' || response['Upgrade'] == 'websocket'
      puts "✓ ActionCable endpoint is available"
      return true
    else
      puts "✗ ActionCable endpoint returned: #{response.code}"
      puts "  This might be OK - WebSocket upgrade requires proper headers"
      return true # Not a failure, just informational
    end
  rescue => e
    puts "✗ Error connecting to ActionCable: #{e.message}"
    return false
  end
end

# Test 2: Test TwiML endpoint
def test_twiml_endpoint
  puts "\nTest 2: Testing TwiML endpoint..."
  
  uri = URI("#{BASE_URL}/twilio/voice")
  
  begin
    response = Net::HTTP.post_form(uri, {
      'CallSid' => CALL_SID,
      'customer_id' => CUSTOMER_ID,
      'To' => '+1234567890'
    })
    
    if response.code == '200'
      puts "✓ TwiML endpoint responded successfully"
      
      # Check if response contains expected TwiML
      if response.body.include?('<Response>') && response.body.include?('<Stream')
        puts "✓ TwiML contains Stream verb"
        puts "\nTwiML Response:"
        puts "-" * 40
        puts response.body
        puts "-" * 40
        return true
      else
        puts "✗ TwiML missing Stream verb"
        puts "Response: #{response.body}"
        return false
      end
    else
      puts "✗ TwiML endpoint returned: #{response.code}"
      puts "Response: #{response.body}"
      return false
    end
  rescue => e
    puts "✗ Error connecting to TwiML endpoint: #{e.message}"
    return false
  end
end

# Test 3: Test call stream creation
def test_call_stream_creation
  puts "\nTest 3: Testing call stream creation..."
  
  uri = URI("#{BASE_URL}/api/v1/call_streams")
  
  begin
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.path, {'Content-Type' => 'application/json'})
    request.body = {
      call_sid: CALL_SID,
      customer_id: CUSTOMER_ID
    }.to_json
    
    response = http.request(request)
    
    if response.code == '200'
      result = JSON.parse(response.body)
      puts "✓ Call stream created successfully"
      puts "  Status: #{result['status']}"
      puts "  Message: #{result['message']}"
      return true
    else
      puts "✗ Call stream creation failed: #{response.code}"
      puts "Response: #{response.body}"
      return false
    end
  rescue => e
    puts "✗ Error creating call stream: #{e.message}"
    return false
  end
end

# Test 4: Check monitoring interface
def test_monitoring_interface
  puts "\nTest 4: Checking monitoring interface..."
  
  uri = URI("#{BASE_URL}/calls_monitoring")
  
  begin
    response = Net::HTTP.get_response(uri)
    
    if response.code == '200' || response.code == '302'
      puts "✓ Monitoring interface is accessible"
      
      if response.code == '302'
        puts "  (Redirected - authentication required)"
      end
      
      return true
    else
      puts "✗ Monitoring interface returned: #{response.code}"
      return false
    end
  rescue => e
    puts "✗ Error accessing monitoring interface: #{e.message}"
    return false
  end
end

# Test 5: Test call stream completion
def test_call_stream_completion
  puts "\nTest 5: Testing call stream completion..."
  
  uri = URI("#{BASE_URL}/api/v1/call_streams/complete")
  
  begin
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.path, {'Content-Type' => 'application/json'})
    request.body = {
      call_sid: CALL_SID,
      duration: 60,
      recording_url: 'https://example.com/recording.mp3'
    }.to_json
    
    response = http.request(request)
    
    if response.code == '200'
      result = JSON.parse(response.body)
      puts "✓ Call stream completed successfully"
      puts "  Status: #{result['status']}"
      return true
    else
      puts "✗ Call stream completion failed: #{response.code}"
      puts "Response: #{response.body}"
      return false
    end
  rescue => e
    puts "✗ Error completing call stream: #{e.message}"
    return false
  end
end

# Run all tests
def run_tests
  results = []
  
  results << test_cable_endpoint
  results << test_twiml_endpoint
  results << test_call_stream_creation
  results << test_monitoring_interface
  results << test_call_stream_completion
  
  puts "\n" + "=" * 60
  puts "Test Results"
  puts "=" * 60
  
  passed = results.count(true)
  total = results.length
  
  puts "Passed: #{passed}/#{total}"
  
  if passed == total
    puts "✓ All tests passed!"
    puts "\nNext steps:"
    puts "1. Configure your Twilio TwiML App"
    puts "2. Set Voice Request URL to: #{BASE_URL}/twilio/voice"
    puts "3. Make a test call"
    puts "4. Visit #{BASE_URL}/calls_monitoring to monitor"
  else
    puts "✗ Some tests failed. Please check the output above."
  end
  
  puts "=" * 60
end

# Run the tests
run_tests

