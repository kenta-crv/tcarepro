# Quick Start: Call Streaming

## What's Been Set Up ✅

All the code for call streaming is now complete! Here's what's ready:

### 1. WebSocket Infrastructure
- ✅ ActionCable mounted at `/cable`
- ✅ Three channels configured:
  - `CallStreamChannel` - Audio to monitoring clients
  - `TwilioMediaChannel` - Transcription streaming
  - `TwilioStreamChannel` - Incoming Twilio streams

### 2. Backend Components
- ✅ `TwilioMediaController` - Generates TwiML for calls
- ✅ `CallsMonitoringController` - Monitoring interface
- ✅ `Api::V1::CallStreamsController` - API endpoints
- ✅ `CallStreamService` - Media processing

### 3. Frontend
- ✅ Monitoring interface at `/calls_monitoring`
- ✅ WebSocket client code with audio player
- ✅ Audio visualizer and controls
- ✅ Live transcript display

### 4. Configuration
- ✅ Production: `wss://tcare.pro/cable`
- ✅ Development: `ws://localhost:3000/cable`
- ✅ Redis configured for production
- ✅ Async adapter for development

## What You Need to Do Next 🔲

### Step 1: Configure Twilio (5 minutes)

1. **Go to Twilio Console** → https://www.twilio.com/console

2. **Create/Edit TwiML App**:
   - Navigate to: Voice → TwiML Apps
   - Voice Request URL: `https://tcare.pro/twilio/voice`
   - Method: POST
   - Save

3. **Configure Phone Number**:
   - Navigate to: Phone Numbers → Active Numbers
   - Select your number
   - Configure with: TwiML App
   - Select the app from step 2
   - Save

### Step 2: Test the Setup (2 minutes)

**Option A: Run Test Script**
```bash
ruby test_call_streaming.rb
```

**Option B: Manual Test**
```bash
# Test TwiML endpoint
curl -X POST http://localhost:3000/twilio/voice \
  -d "CallSid=TEST123" \
  -d "customer_id=1" \
  -d "To=+1234567890"
```

### Step 3: Make a Real Call (1 minute)

1. Call your Twilio number
2. Visit: `https://tcare.pro/calls_monitoring`
3. Click "Listen" on the active call
4. Hear the audio stream!

## How It Works

```
📞 Call comes in
    ↓
🔷 Twilio sends to: /twilio/voice
    ↓
📄 TwiML returned with <Stream url="wss://tcare.pro/cable" />
    ↓
🔌 Twilio opens WebSocket to /cable
    ↓
📡 Audio streams through ActionCable
    ↓
🎧 Browser receives and plays audio
```

## Key Endpoints

| Endpoint | Purpose |
|----------|---------|
| `POST /twilio/voice` | Twilio webhook (generates TwiML) |
| `GET /calls_monitoring` | View active calls |
| `GET /calls_monitoring/:id` | Monitor specific call |
| `WS /cable` | WebSocket for streaming |
| `POST /api/v1/call_streams` | Create stream |
| `POST /api/v1/call_streams/complete` | End stream |

## Troubleshooting

### "No active calls"
- Make sure you called the Twilio number
- Check that TwiML App is configured correctly
- Verify phone number is using the TwiML App

### "WebSocket connection failed"
- Check Redis is running: `redis-cli ping`
- Verify ActionCable URL in environment config
- Check browser console for errors

### "No audio playing"
- Check browser console for WebSocket messages
- Verify SSL certificate (production needs HTTPS)
- Click "Play" button in the interface

### "Connection refused"
- Make sure Rails server is running
- Check firewall allows WebSocket connections
- Verify port 3000 (dev) or 443 (prod) is open

## Testing Checklist

- [ ] Rails server running
- [ ] Redis running (production)
- [ ] Twilio TwiML App configured
- [ ] Phone number linked to TwiML App
- [ ] SSL certificate valid (production)
- [ ] Test script passes
- [ ] Can access /calls_monitoring
- [ ] Can make test call
- [ ] Audio plays in browser

## Files Modified/Created

### New Files
- `app/channels/twilio_stream_channel.rb` - Twilio WebSocket handler
- `test_call_streaming.rb` - Test script
- `CALL_STREAMING_COMPLETE_SETUP.md` - Full documentation
- `QUICK_START_CALL_STREAMING.md` - This file

### Modified Files
- `config/routes.rb` - Added ActionCable mount
- `config/environments/production.rb` - ActionCable config
- `config/environments/development.rb` - ActionCable config
- `app/controllers/twilio_media_controller.rb` - Enhanced TwiML
- `app/controllers/twilio_media_stream_controller.rb` - WebSocket handling
- `app/services/call_stream_service.rb` - Audio format info

### Existing Files (Already Working)
- `app/channels/call_stream_channel.rb`
- `app/channels/twilio_media_channel.rb`
- `app/controllers/calls_monitoring_controller.rb`
- `app/controllers/api/v1/call_streams_controller.rb`
- `app/views/calls_monitoring/index.html.erb`
- `app/views/calls_monitoring/show.html.erb`

## Need Help?

1. **Check logs**: `tail -f log/development.log`
2. **Check Twilio**: https://www.twilio.com/console/debugger
3. **Browser console**: F12 → Console tab
4. **Read full docs**: `CALL_STREAMING_COMPLETE_SETUP.md`

## Summary

✅ **Code is complete and ready!**

🔲 **You just need to**:
1. Configure Twilio TwiML App (5 min)
2. Run test script (2 min)
3. Make a test call (1 min)

**Total time to go live: ~8 minutes** 🚀

---

Good luck! The WebSocket infrastructure is all set up and ready to stream calls.

