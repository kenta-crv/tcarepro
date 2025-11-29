# VAPI Integration - Quick Start

## ✅ What's Been Created

1. **VapiWebsocketService** - Connects to VAPI's WebSocket and processes audio
2. **VapiWebhooksController** - Receives VAPI webhooks and starts streaming
3. **Updated CallsMonitoringController** - Shows calls from cache (VAPI calls)
4. **Route added** - `POST /vapi/webhook`

## 🚀 Setup Steps

### 1. Install Gems (on VPS)
```bash
bundle install
```

### 2. Configure n8n Workflow

After your VAPI call node, add an **HTTP Request** node:

**URL:** `https://tcare.pro/vapi/webhook`

**Method:** POST

**Body:**
```json
{
  "monitor": {
    "listenUrl": "{{$json.monitor.listenUrl}}",
    "controlUrl": "{{$json.monitor.controlUrl}}"
  },
  "callSid": "{{$json.callSid}}",
  "callId": "{{$json.id}}",
  "to": "{{$json.customer.number}}"
}
```

### 3. Restart Rails Server
```bash
# On VPS
sudo systemctl restart tcarepro
# Or if running manually:
pkill -f puma
bundle exec puma -C config/puma.rb
```

## 🎯 How to Test

1. Make a call via n8n → VAPI
2. Check logs: `tail -f log/production.log | grep VAPI`
3. Open: `https://tcare.pro/calls_monitoring`
4. You should see the call in the list
5. Click "Listen" to monitor with audio + transcript

## 📋 Expected Log Output

When working correctly, you should see:
```
VAPI WEBHOOK RECEIVED
CallSid: CA123...
VAPI WebSocket service started for call CA123...
Connected to VAPI WebSocket for call ...
Speech-to-text service started for call CA123...
```

## 🔍 Troubleshooting

### Call doesn't appear
- Check if webhook was called: `grep VAPI log/production.log`
- Check if customer exists for phone number
- Check cache: `Rails.cache.read("call_stream_CA123...")`

### No audio/transcript
- Check WebSocket connection in logs
- Verify Google credentials are set
- Check browser console for errors

## 📝 Files Created

- `app/services/vapi_websocket_service.rb`
- `app/controllers/vapi_webhooks_controller.rb`
- `VAPI_INTEGRATION_SETUP.md` (full documentation)

