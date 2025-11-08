# Twilio Live Call Streaming Setup Guide

This guide explains how to configure Twilio to enable live call streaming with our application.

## Prerequisites

- A Twilio account with API access
- Your Twilio phone number(s) configured
- Access to the Twilio console

## Configuration Steps

### 1. Set Up TwiML Application

1. Log in to your [Twilio Console](https://www.twilio.com/console)
2. Navigate to "Voice" > "TwiML Apps"
3. Create a new TwiML App or edit your existing one
4. Set the Voice Request URL to your application's streaming endpoint:
   ```
   https://tcare.pro/api/v1/call_streams/stream
   ```
5. Set the Request Method to "POST"
6. Save your changes

### 2. Configure Your Twilio Number

1. In the Twilio Console, navigate to "Phone Numbers" > "Manage" > "Active Numbers"
2. Select the phone number you want to use for live streaming
3. Under "Voice & Fax" section, set the following:
   - Configure with: "TwiML App"
   - TwiML App: Select the app you created in step 1
4. Save your changes

### 3. Update Your TwiML for Incoming Calls

When a call comes in, you need to use the `<Stream>` verb in your TwiML response. Here's an example:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Say>This call is being monitored for quality assurance purposes.</Say>
  <Stream url="wss://tcare.pro/api/v1/call_streams/stream" />
  <Dial>
    <Number>+1234567890</Number>
  </Dial>
</Response>
```

You can generate this TwiML dynamically in your application or use a TwiML Bin in the Twilio Console.

### 4. Testing the Setup

1. Use the provided test script to simulate a call:
   ```
   ruby test_api.rb --mode stream --customer_id 12345
   ```

2. Visit the live call monitoring interface at:
   ```
   https://tcare.pro/calls_monitoring
   ```

3. You should see the test call appear in the list and be able to listen to it.

## Troubleshooting

### No Audio Stream

- Verify that your Twilio number is correctly configured with the TwiML App
- Check that the Stream URL is correct and accessible from the internet
- Ensure your server's WebSocket endpoint is properly configured

### Connection Issues

- Check your server logs for WebSocket connection errors
- Verify that your server allows WebSocket connections
- Ensure your SSL certificate is valid (Twilio requires HTTPS)

### Audio Quality Issues

- Check your network bandwidth and latency
- Consider adjusting the audio buffer size in the client application

## Additional Resources

- [Twilio Stream Documentation](https://www.twilio.com/docs/voice/twiml/stream)
- [WebSocket API Documentation](https://www.twilio.com/docs/voice/tutorials/consuming-media-streams-using-websockets)
- [Media Streams API Documentation](https://www.twilio.com/docs/voice/tutorials/consuming-media-streams-using-websockets-python-and-javascript)
