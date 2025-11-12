# Complete Call Streaming Setup Guide

This guide provides complete instructions for setting up Twilio call streaming with WebSocket support.

## Overview

The call streaming system uses:
- **ActionCable** (Rails WebSocket framework) for real-time communication
- **Twilio Media Streams** for audio streaming
- **Redis** (in production) for ActionCable message broadcasting
- **Browser WebSocket API** for client-side audio playback

## Architecture

```
Twilio Call → WebSocket (wss://tcare.pro/cable)
                    ↓
            ActionCable Server
                    ↓
        TwilioStreamChannel / CallStreamChannel
                    ↓
            CallStreamService
                    ↓
        Broadcast to monitoring clients
                    ↓
        Browser receives audio → Web Audio API → Playback
```

## Prerequisites

1. **Ruby on Rails** application (already set up)
2. **Redis** server (for production)
3. **Twilio account** with API credentials
4. **SSL certificate** (Twilio requires WSS - secure WebSocket)
5. **Domain name** (e.g., tcare.pro)

## Installation Steps

### 1. Verify ActionCable is Mounted

The routes file should have:
```ruby
mount ActionCable.server => '/cable'
```

✅ **Status**: Already configured in `config/routes.rb`

### 2. Configure Redis for Production

Edit `config/cable.yml`:
```yaml
production:
  adapter: redis
  url: redis://localhost:6379/1
  channel_prefix: smart_production
```

✅ **Status**: Already configured

### 3. Configure Environment Settings

**Production** (`config/environments/production.rb`):
```ruby
config.action_cable.url = 'wss://tcare.pro/cable'
config.action_cable.allowed_request_origins = [ 
  'https://tcare.pro', 
  'http://tcare.pro',
  /https:\/\/tcare\.pro/,
  /http:\/\/tcare\.pro/
]
```

**Development** (`config/environments/development.rb`):
```ruby
config.action_cable.url = 'ws://localhost:3000/cable'
config.action_cable.allowed_request_origins = [ 
  'http://localhost:3000',
  /http:\/\/localhost:*/
]
```

✅ **Status**: Already configured

### 4. WebSocket Channels

The following channels are set up:

#### CallStreamChannel
Handles audio streaming to monitoring clients.
- Location: `app/channels/call_stream_channel.rb`
- Subscribes to: `call_stream_#{call_id}`

#### TwilioMediaChannel
Handles transcription streaming.
- Location: `app/channels/twilio_media_channel.rb`
- Subscribes to: `call_audio_#{call_sid}` and `call_transcript_#{call_sid}`

#### TwilioStreamChannel (NEW)
Handles incoming WebSocket connections from Twilio.
- Location: `app/channels/twilio_stream_channel.rb`
- Processes Twilio media stream events: start, media, stop

✅ **Status**: All channels configured

### 5. Controllers

#### TwilioMediaController
Generates TwiML responses for incoming calls.
- Location: `app/controllers/twilio_media_controller.rb`
- Endpoint: `POST /twilio/voice`

#### CallsMonitoringController
Displays monitoring interface.
- Location: `app/controllers/calls_monitoring_controller.rb`
- Routes:
  - `GET /calls_monitoring` - List active calls
  - `GET /calls_monitoring/:id` - Monitor specific call

#### Api::V1::CallStreamsController
API endpoints for call streaming.
- Location: `app/controllers/api/v1/call_streams_controller.rb`
- Routes:
  - `POST /api/v1/call_streams` - Create stream
  - `POST /api/v1/call_streams/stream` - Receive audio
  - `POST /api/v1/call_streams/complete` - End stream

✅ **Status**: All controllers configured

### 6. Services

#### CallStreamService
Processes and broadcasts media chunks.
- Location: `app/services/call_stream_service.rb`
- Methods:
  - `process_media(call_sid, media_chunk)` - Broadcast audio
  - `start_call(call_sid, customer_id)` - Start event
  - `end_call(call_sid)` - End event

✅ **Status**: Service configured

## Twilio Configuration

### Step 1: Configure TwiML App

1. Log in to [Twilio Console](https://www.twilio.com/console)
2. Navigate to **Voice** → **TwiML Apps**
3. Create a new TwiML App or edit existing
4. Set **Voice Request URL**:
   ```
   https://tcare.pro/twilio/voice
   ```
5. Set **Request Method**: `POST`
6. Save changes

### Step 2: Configure Phone Number

1. Go to **Phone Numbers** → **Manage** → **Active Numbers**
2. Select your phone number
3. Under **Voice & Fax**:
   - **Configure with**: TwiML App
   - **TwiML App**: Select the app from Step 1
4. Set **Status Callback URL** (optional):
   ```
   https://tcare.pro/twilio/status
   ```
5. Save changes

### Step 3: Test TwiML Response

You can test the TwiML endpoint:

```bash
curl -X POST https://tcare.pro/twilio/voice \
  -d "CallSid=TEST123" \
  -d "customer_id=1" \
  -d "To=+1234567890"
```

Expected response:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Say language="en-US">This call is being monitored and transcribed for quality assurance purposes.</Say>
  <Start>
    <Stream url="wss://tcare.pro/cable"/>
  </Start>
  <Dial>+1234567890</Dial>
</Response>
```

## Frontend Usage

### Monitoring Interface

1. Navigate to: `https://tcare.pro/calls_monitoring`
2. View list of active calls
3. Click **Listen** on any call to monitor
4. Audio player with controls:
   - Play/Pause/Stop buttons
   - Volume control
   - Audio visualizer
   - Live transcript (if available)
   - Call events log

### WebSocket Connection (Automatic)

The frontend automatically:
1. Connects to WebSocket at `/cable`
2. Subscribes to `CallStreamChannel` for audio
3. Subscribes to `TwilioMediaChannel` for transcripts
4. Decodes and plays audio using Web Audio API
5. Displays waveform visualization

## Testing

### Test Script

A test script is provided at `test_api.rb`:

```bash
ruby test_api.rb --mode stream --customer_id 12345
```

### Manual Testing

1. **Start Rails server**:
   ```bash
   rails server
   ```

2. **Start Redis** (for production):
   ```bash
   redis-server
   ```

3. **Make a test call** through Twilio

4. **Monitor the call**:
   - Visit `/calls_monitoring`
   - Click on the active call
   - Verify audio playback

### Check WebSocket Connection

Open browser console and check for:
```
Audio WebSocket connected
Audio subscription confirmed
Receiving audio stream...
```

## Troubleshooting

### No Audio Stream

**Problem**: Audio not playing in browser

**Solutions**:
- Check browser console for WebSocket errors
- Verify ActionCable is mounted: `rake routes | grep cable`
- Check Redis is running: `redis-cli ping`
- Verify SSL certificate is valid
- Check Twilio webhook logs in Twilio Console

### WebSocket Connection Failed

**Problem**: "WebSocket disconnected" in console

**Solutions**:
- Verify `config.action_cable.url` matches your domain
- Check `allowed_request_origins` includes your domain
- Ensure port 6379 (Redis) is open
- Check firewall rules for WebSocket connections

### Twilio Not Connecting

**Problem**: Calls work but no streaming

**Solutions**:
- Verify TwiML includes `<Stream>` verb
- Check TwiML App configuration in Twilio Console
- Ensure WebSocket URL is `wss://` (secure)
- Check Twilio debugger for connection errors

### Audio Format Issues

**Problem**: Audio plays but sounds distorted

**Solutions**:
- Twilio sends audio in **mulaw** format
- Browser needs to decode mulaw to PCM
- Check `CallStreamService.process_media` includes format info
- Verify Web Audio API is decoding correctly

## Security Considerations

1. **Authentication**: Only authenticated users can access monitoring
   - Admins: `authenticate_admin!`
   - Users: `authenticate_user!`

2. **CSRF Protection**: Disabled for API endpoints
   - `skip_before_action :verify_authenticity_token`

3. **WebSocket Origin Validation**: 
   - `allowed_request_origins` configured
   - Prevents unauthorized WebSocket connections

4. **SSL/TLS**: Required for production
   - Twilio requires `wss://` (secure WebSocket)
   - Configure SSL certificate on server

5. **Call Data**: Stored in Rails cache
   - Expires after 1 hour
   - Contains: call_sid, customer_id, timestamps

## Performance Optimization

1. **Redis**: Use Redis in production for better performance
2. **Connection Pooling**: ActionCable handles this automatically
3. **Audio Buffering**: Frontend queues audio chunks
4. **Cleanup**: WebSocket connections cleaned up on disconnect

## Monitoring & Logging

Check logs for WebSocket activity:

```bash
# Development
tail -f log/development.log | grep -i "cable\|websocket\|stream"

# Production
tail -f log/production.log | grep -i "cable\|websocket\|stream"
```

## Next Steps

1. ✅ ActionCable mounted
2. ✅ WebSocket channels configured
3. ✅ Controllers set up
4. ✅ Frontend JavaScript ready
5. ✅ Environment configurations complete
6. 🔲 Configure Twilio TwiML App
7. 🔲 Configure Twilio phone number
8. 🔲 Test with real call
9. 🔲 Deploy to production
10. 🔲 Monitor and optimize

## Additional Resources

- [ActionCable Overview](https://guides.rubyonrails.org/action_cable_overview.html)
- [Twilio Media Streams](https://www.twilio.com/docs/voice/twiml/stream)
- [Web Audio API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)
- [Redis Quick Start](https://redis.io/topics/quickstart)

## Support

For issues or questions:
1. Check logs: `log/development.log` or `log/production.log`
2. Check Twilio debugger: https://www.twilio.com/console/debugger
3. Verify WebSocket connection in browser console
4. Review this documentation

---

**Last Updated**: November 2025
**Version**: 1.0

