# WebSocket Call Streaming Flow Diagram

## Complete System Architecture

```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                         TWILIO SIDE                              ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    📞 Customer calls Twilio number
           │
           ▼
    ┌─────────────────┐
    │  Twilio Server  │
    └────────┬────────┘
             │ HTTP POST
             │
             ▼
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                        YOUR RAILS APP                            ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    POST /twilio/voice
           │
           ▼
    ┌──────────────────────────┐
    │ TwilioMediaController    │
    │  - Get CallSid           │
    │  - Create call record    │
    │  - Store in cache        │
    │  - Generate TwiML        │
    └────────┬─────────────────┘
             │
             │ Returns TwiML:
             │ <Response>
             │   <Stream url="wss://tcare.pro/cable" />
             │   <Dial>+1234567890</Dial>
             │ </Response>
             │
             ▼
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                    WEBSOCKET CONNECTION                          ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    Twilio opens WebSocket
           │
           │ WSS Upgrade Request
           │
           ▼
    wss://tcare.pro/cable
           │
           ▼
    ┌──────────────────────────┐
    │   ActionCable Server     │
    │   (Rails WebSocket)      │
    └────────┬─────────────────┘
             │
             ▼
    ┌──────────────────────────┐
    │  TwilioStreamChannel     │
    │  - subscribed()          │
    │  - receive(data)         │
    └────────┬─────────────────┘
             │
             │ Receives JSON:
             │ {
             │   "event": "start",
             │   "start": {
             │     "streamSid": "...",
             │     "callSid": "..."
             │   }
             │ }
             │
             ▼
    ┌──────────────────────────┐
    │  handle_stream_start()   │
    │  - Store stream info     │
    │  - Broadcast event       │
    └────────┬─────────────────┘
             │
             │ Continuous stream:
             │ {
             │   "event": "media",
             │   "media": {
             │     "payload": "base64...",
             │     "timestamp": 123456
             │   }
             │ }
             │
             ▼
    ┌──────────────────────────┐
    │  handle_media_data()     │
    │  - Extract audio payload │
    │  - Find call_sid         │
    └────────┬─────────────────┘
             │
             ▼
    ┌──────────────────────────┐
    │   CallStreamService      │
    │   process_media()        │
    └────────┬─────────────────┘
             │
             │ ActionCable.server.broadcast(
             │   "call_stream_#{call_sid}",
             │   { chunk: payload, timestamp: ... }
             │ )
             │
             ▼
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                      MONITORING CLIENT                           ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    User visits /calls_monitoring
           │
           ▼
    ┌──────────────────────────┐
    │ CallsMonitoringController│
    │  - List active calls     │
    └────────┬─────────────────┘
             │
             ▼
    User clicks "Listen"
           │
           ▼
    GET /calls_monitoring/:call_sid
           │
           ▼
    ┌──────────────────────────┐
    │  show.html.erb           │
    │  - Display call info     │
    │  - Load JavaScript       │
    └────────┬─────────────────┘
             │
             │ JavaScript creates WebSocket:
             │ new WebSocket('wss://tcare.pro/cable')
             │
             ▼
    ┌──────────────────────────┐
    │  Browser WebSocket       │
    │  - Connect to /cable     │
    └────────┬─────────────────┘
             │
             │ Send subscription:
             │ {
             │   "command": "subscribe",
             │   "identifier": {
             │     "channel": "CallStreamChannel",
             │     "call_id": "..."
             │   }
             │ }
             │
             ▼
    ┌──────────────────────────┐
    │  CallStreamChannel       │
    │  subscribed()            │
    │  stream_from(call_id)    │
    └────────┬─────────────────┘
             │
             │ Receives broadcasts:
             │ { chunk: "base64...", timestamp: ... }
             │
             ▼
    ┌──────────────────────────┐
    │  JavaScript Handler      │
    │  handleAudioMessage()    │
    │  - Decode base64         │
    │  - Add to queue          │
    └────────┬─────────────────┘
             │
             ▼
    ┌──────────────────────────┐
    │  Web Audio API           │
    │  - Decode mulaw → PCM    │
    │  - Create AudioBuffer    │
    │  - Play audio            │
    └────────┬─────────────────┘
             │
             ▼
    🔊 User hears audio
    📊 Visualizer shows waveform
    📝 Transcript appears
```

## Data Flow Detail

### 1. Call Initiation
```
Customer → Twilio → POST /twilio/voice → TwiML Response
```

### 2. WebSocket Setup
```
Twilio reads TwiML → Opens WSS connection → ActionCable accepts
```

### 3. Audio Streaming
```
Twilio (audio) → WebSocket → TwilioStreamChannel → CallStreamService → Broadcast
```

### 4. Client Receiving
```
Broadcast → CallStreamChannel → Browser WebSocket → JavaScript → Web Audio API → Speaker
```

## Message Format Examples

### From Twilio to Server

**Start Event:**
```json
{
  "event": "start",
  "sequenceNumber": "1",
  "start": {
    "streamSid": "MZ18c6d5b37fb0a0c0c0c0c0c0c0c0c0c",
    "accountSid": "AC123...",
    "callSid": "CA456...",
    "tracks": ["inbound"],
    "mediaFormat": {
      "encoding": "audio/x-mulaw",
      "sampleRate": 8000,
      "channels": 1
    }
  },
  "streamSid": "MZ18c6d5b37fb0a0c0c0c0c0c0c0c0c0c"
}
```

**Media Event:**
```json
{
  "event": "media",
  "sequenceNumber": "2",
  "media": {
    "track": "inbound",
    "chunk": "1",
    "timestamp": "5",
    "payload": "no+JhoaJjpGUk5OPi4+L..."
  },
  "streamSid": "MZ18c6d5b37fb0a0c0c0c0c0c0c0c0c0c"
}
```

**Stop Event:**
```json
{
  "event": "stop",
  "sequenceNumber": "3",
  "stop": {
    "accountSid": "AC123...",
    "callSid": "CA456..."
  },
  "streamSid": "MZ18c6d5b37fb0a0c0c0c0c0c0c0c0c0c"
}
```

### From Server to Browser

**Call Started:**
```json
{
  "event": "call_started",
  "call_sid": "CA456...",
  "customer_id": "123",
  "timestamp": 1699564800.123
}
```

**Audio Chunk:**
```json
{
  "chunk": "no+JhoaJjpGUk5OPi4+L...",
  "timestamp": 1699564801.456,
  "format": "mulaw"
}
```

**Call Ended:**
```json
{
  "event": "call_ended",
  "call_sid": "CA456...",
  "timestamp": 1699564900.789
}
```

## Channel Subscriptions

### TwilioStreamChannel (Server-side)
```ruby
# Receives from Twilio
stream_from "twilio_stream_#{stream_sid}"
```

### CallStreamChannel (Client-side)
```javascript
// Subscribes to call audio
{
  channel: 'CallStreamChannel',
  call_id: 'CA456...'
}
```

### TwilioMediaChannel (Client-side)
```javascript
// Subscribes to transcripts
{
  channel: 'TwilioMediaChannel',
  call_sid: 'CA456...'
}
```

## Redis Pub/Sub (Production)

```
ActionCable.server.broadcast()
           │
           ▼
    ┌──────────────┐
    │    Redis     │
    │   Pub/Sub    │
    └──────┬───────┘
           │
           ├─────► Subscriber 1 (Browser A)
           ├─────► Subscriber 2 (Browser B)
           └─────► Subscriber N (Browser N)
```

## Connection Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│                     Connection States                        │
└─────────────────────────────────────────────────────────────┘

1. CONNECTING
   - WebSocket handshake
   - Upgrade from HTTP to WS

2. OPEN
   - Connection established
   - Ready to send/receive

3. SUBSCRIBED
   - Channel subscription confirmed
   - Receiving broadcasts

4. STREAMING
   - Audio data flowing
   - Real-time playback

5. CLOSING
   - Call ended or user left page
   - Cleanup initiated

6. CLOSED
   - Connection terminated
   - Resources freed
```

## Error Handling Flow

```
Error occurs
    │
    ▼
Log error
    │
    ▼
Attempt reconnection
    │
    ├─ Success → Resume streaming
    │
    └─ Failure → Show error to user
                  │
                  └─ Retry after 3 seconds
```

## Summary

**Key Points:**
1. ✅ WebSocket uses ActionCable framework
2. ✅ Twilio connects directly to `/cable` endpoint
3. ✅ Audio streams in real-time through channels
4. ✅ Multiple clients can monitor same call
5. ✅ Redis handles message distribution in production
6. ✅ Browser decodes and plays audio using Web Audio API

**Critical URLs:**
- Twilio webhook: `https://tcare.pro/twilio/voice`
- WebSocket endpoint: `wss://tcare.pro/cable`
- Monitoring interface: `https://tcare.pro/calls_monitoring`

**Data Format:**
- From Twilio: mulaw, base64 encoded, 8kHz
- To Browser: Same format, decoded by Web Audio API
- Message protocol: JSON over WebSocket

---

This diagram shows the complete flow from incoming call to audio playback in the browser!

