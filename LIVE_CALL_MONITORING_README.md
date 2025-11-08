# Live Call Monitoring Implementation

This document provides an overview of the live call monitoring feature that has been implemented in the TCare Pro application.

## Features

- Real-time monitoring of active calls
- Audio streaming directly to the browser
- Visual audio waveform display
- Call event logging
- Customer information display

## Components

### Backend

1. **WebSocket Server**
   - Uses ActionCable for WebSocket communication
   - Handles real-time audio streaming

2. **Call Stream Channel**
   - Manages WebSocket subscriptions for each call
   - Broadcasts audio data to subscribed clients

3. **API Endpoints**
   - `/api/v1/call_streams` - Initiates a call stream
   - `/api/v1/call_streams/stream` - Receives audio data from Twilio
   - `/api/v1/call_streams/complete` - Handles call completion

4. **Call Stream Service**
   - Processes and broadcasts audio data
   - Manages call events

### Frontend

1. **Call Monitoring Interface**
   - List view of active calls
   - Detailed view for individual calls
   - Audio controls (play, pause, stop)
   - Volume control
   - Audio visualizer
   - Call event log

## How It Works

1. When a call is initiated through Twilio, the TwiML includes a `<Stream>` verb that points to our streaming endpoint.
2. Twilio opens a WebSocket connection to our server and starts sending audio data.
3. Our server processes the audio data and broadcasts it to any connected clients via ActionCable.
4. Users can access the live call monitoring interface at `/calls_monitoring` to see active calls.
5. When a user selects a call to monitor, their browser connects to the appropriate WebSocket channel and starts receiving audio data.
6. The audio data is processed and played through the browser's audio system, with a visual representation on the waveform display.

## Testing

A test script (`test_api.rb`) has been provided to simulate call streaming:

```
ruby test_api.rb --mode stream --customer_id 12345
```

## Configuration

See `TWILIO_STREAMING_SETUP.md` for detailed instructions on configuring Twilio for live call streaming.

## Security Considerations

- Only authenticated users (admins or regular users) can access the call monitoring interface
- WebSocket connections are authenticated using the same session as the web interface
- All communication is encrypted using HTTPS/WSS

## Future Improvements

- Add ability to join the call (not just listen)
- Implement call recording directly from the monitoring interface
- Add more detailed call analytics
- Implement call quality metrics
