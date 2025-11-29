# VAPI Integration Setup Guide

This guide explains how to set up live call streaming and transcription with VAPI using WebSocket connections.

## Overview

Instead of trying to get Twilio to call your webhook (which VAPI doesn't support for outbound calls), we connect directly to VAPI's WebSocket to get the audio stream.

## How It Works

```
1. n8n triggers VAPI call
   ↓
2. VAPI makes call and returns monitor URLs
   ↓
3. n8n sends monitor URLs to: POST /vapi/webhook
   ↓
4. Your app connects to VAPI's WebSocket (listenUrl)
   ↓
5. Receives audio stream from VAPI
   ↓
6. Processes through SpeechToTextService (Google Cloud)
   ↓
7. Broadcasts to /calls_monitoring via ActionCable
   ↓
8. ✅ Live streaming + transcription works!
```

## Setup Steps

### Step 1: Install Dependencies

```bash
bundle install
```

This will install the `faye-websocket` gem needed for WebSocket connections.

### Step 2: Configure Environment Variables

Make sure your `.env` file has:

```bash
GOOGLE_APPLICATION_CREDENTIALS="config/credentials/google-speech-credentials.json"
```

### Step 3: Configure n8n Workflow

After your VAPI call node, add an HTTP Request node:

**URL:** `https://tcare.pro/vapi/webhook`

**Method:** POST

**Body (JSON):**
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

**Headers:**
- `Content-Type: application/json`

### Step 4: Test the Setup

1. Make a test call via n8n → VAPI
2. Check Rails logs for:
   - `VAPI WEBHOOK RECEIVED`
   - `VAPI WebSocket service started`
   - `Connected to VAPI WebSocket`
3. Open: `https://tcare.pro/calls_monitoring`
4. You should see the call in the list
5. Click "Listen" to monitor with audio and transcript

## API Endpoints

### POST /vapi/webhook

Receives VAPI's monitor URLs and starts WebSocket connection.

**Request Body:**
```json
{
  "monitor": {
    "listenUrl": "wss://phone-call-websocket.vapi.ai/.../listen",
    "controlUrl": "https://phone-call-websocket.vapi.ai/.../control"
  },
  "callSid": "CA1234567890",
  "callId": "019acee5-4d30-700f-8d7c-396c8e90cdf1",
  "to": "+1234567890"
}
```

**Response:**
```json
{
  "status": "success",
  "message": "WebSocket connection started",
  "call_sid": "CA1234567890"
}
```

## Components

### VapiWebsocketService

- Connects to VAPI's WebSocket
- Receives audio stream
- Processes through Google Speech-to-Text
- Broadcasts to monitoring clients

### VapiWebhooksController

- Receives VAPI webhook with monitor URLs
- Creates/updates call records
- Starts WebSocket service
- Handles customer lookup by phone number

## Monitoring Interface

Visit: `https://tcare.pro/calls_monitoring`

You'll see:
- List of active calls (from database + cache)
- Click "Listen" to monitor specific call
- Live audio streaming
- Live transcript appearing in real-time
- Audio visualizer
- Call events log

## Troubleshooting

### Call doesn't appear in monitoring

1. Check Rails logs for webhook receipt:
   ```bash
   tail -f log/production.log | grep VAPI
   ```

2. Check if WebSocket connected:
   ```bash
   tail -f log/production.log | grep "VAPI WebSocket"
   ```

3. Verify customer exists for the phone number
   - Calls without customers won't create DB records
   - But they should still appear in monitoring via cache

### No audio streaming

1. Check WebSocket connection in logs
2. Verify Google credentials are set
3. Check browser console for WebSocket errors

### No transcription

1. Verify `GOOGLE_APPLICATION_CREDENTIALS` is set
2. Check Google Cloud Speech API is enabled
3. Check logs for transcription errors

## Files Created/Modified

### New Files
- `app/services/vapi_websocket_service.rb` - WebSocket service
- `app/controllers/vapi_webhooks_controller.rb` - Webhook handler
- `VAPI_INTEGRATION_SETUP.md` - This file

### Modified Files
- `Gemfile` - Added `faye-websocket` gem
- `config/routes.rb` - Added `/vapi/webhook` route
- `app/controllers/calls_monitoring_controller.rb` - Shows calls from cache

## Notes

- Calls without matching customers won't create DB records but will still be monitored
- WebSocket connections are managed in background threads
- Audio is processed in real-time for transcription
- Transcripts are saved to database when final

