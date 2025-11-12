# Call Streaming Deployment Checklist

Use this checklist to deploy and test the call streaming feature.

## Pre-Deployment Checklist

### Code Verification
- [x] ActionCable mounted in routes.rb
- [x] WebSocket channels created
- [x] Controllers configured
- [x] Services implemented
- [x] Frontend JavaScript ready
- [x] Environment configs updated
- [x] No linter errors

### Dependencies
- [ ] Rails server can start without errors
- [ ] Redis installed (for production)
- [ ] SSL certificate valid (for production)
- [ ] Twilio account active
- [ ] Twilio API credentials available

## Development Testing

### 1. Start Services
```bash
# Terminal 1: Start Rails
rails server

# Terminal 2: Start Redis (if testing production mode)
redis-server
```
- [ ] Rails server started successfully
- [ ] Redis running (production only)

### 2. Run Test Script
```bash
ruby test_call_streaming.rb
```
- [ ] Test 1: ActionCable endpoint ✓
- [ ] Test 2: TwiML endpoint ✓
- [ ] Test 3: Call stream creation ✓
- [ ] Test 4: Monitoring interface ✓
- [ ] Test 5: Call completion ✓

### 3. Manual Verification
```bash
# Check routes
rake routes | grep cable
# Should show: /cable

# Check TwiML
curl -X POST http://localhost:3000/twilio/voice \
  -d "CallSid=TEST123" \
  -d "customer_id=1" \
  -d "To=+1234567890"
# Should return XML with <Stream> tag
```
- [ ] `/cable` route exists
- [ ] TwiML returns valid XML
- [ ] TwiML contains `<Stream url="wss://...">` 

### 4. Browser Testing
1. Open: http://localhost:3000/calls_monitoring
2. Open browser console (F12)
3. Check for errors

- [ ] Page loads without errors
- [ ] No JavaScript errors in console
- [ ] Can see "No active calls" message (or list of calls)

## Twilio Configuration

### 1. Create TwiML App
1. Go to: https://www.twilio.com/console/voice/twiml/apps
2. Click "Create new TwiML App"
3. Fill in:
   - **Friendly Name**: TCare Pro Call Streaming
   - **Voice Request URL**: `https://tcare.pro/twilio/voice`
   - **Request Method**: POST
   - **Status Callback URL**: `https://tcare.pro/twilio/status` (optional)

- [ ] TwiML App created
- [ ] Voice Request URL set correctly
- [ ] Method set to POST

### 2. Configure Phone Number
1. Go to: https://www.twilio.com/console/phone-numbers/incoming
2. Click on your phone number
3. Under "Voice & Fax":
   - **Configure with**: TwiML App
   - **TwiML App**: Select "TCare Pro Call Streaming"
4. Click Save

- [ ] Phone number configured
- [ ] Linked to TwiML App
- [ ] Changes saved

### 3. Verify Twilio Configuration
1. Go to: https://www.twilio.com/console/debugger
2. Make a test call to your Twilio number
3. Check debugger for any errors

- [ ] Call appears in debugger
- [ ] No errors in debugger
- [ ] Webhook called successfully

## Production Deployment

### 1. Environment Setup
```bash
# Check production config
cat config/environments/production.rb | grep action_cable

# Should show:
# config.action_cable.url = 'wss://tcare.pro/cable'
# config.action_cable.allowed_request_origins = [...]
```
- [ ] ActionCable URL configured
- [ ] Allowed origins configured
- [ ] Redis configured in cable.yml

### 2. SSL Certificate
```bash
# Test SSL
curl https://tcare.pro
# Should return 200 OK

# Test WebSocket upgrade
curl -i -N -H "Connection: Upgrade" \
     -H "Upgrade: websocket" \
     -H "Host: tcare.pro" \
     -H "Origin: https://tcare.pro" \
     https://tcare.pro/cable
# Should return 101 Switching Protocols
```
- [ ] SSL certificate valid
- [ ] HTTPS working
- [ ] WebSocket upgrade working

### 3. Redis Setup
```bash
# Check Redis is running
redis-cli ping
# Should return: PONG

# Check Redis config
redis-cli CONFIG GET maxmemory
redis-cli CONFIG GET maxmemory-policy
```
- [ ] Redis running
- [ ] Redis accessible
- [ ] Memory limits configured

### 4. Deploy Code
```bash
# Pull latest code
git pull origin vickyjay-branch

# Install dependencies
bundle install

# Precompile assets
RAILS_ENV=production rake assets:precompile

# Restart server
# (depends on your deployment method)
```
- [ ] Code deployed
- [ ] Dependencies installed
- [ ] Assets precompiled
- [ ] Server restarted

### 5. Verify Production
```bash
# Test production TwiML
curl -X POST https://tcare.pro/twilio/voice \
  -d "CallSid=PROD_TEST" \
  -d "customer_id=1" \
  -d "To=+1234567890"

# Check logs
tail -f log/production.log
```
- [ ] Production TwiML working
- [ ] No errors in logs
- [ ] WebSocket connections accepted

## Live Testing

### 1. Make Test Call
1. Call your Twilio number from any phone
2. Listen for greeting: "This call is being monitored..."
3. Call should connect to destination

- [ ] Call connects
- [ ] Greeting plays
- [ ] Call forwards to destination

### 2. Monitor Call
1. Open: https://tcare.pro/calls_monitoring
2. Should see active call in list
3. Click "Listen" button

- [ ] Call appears in list
- [ ] Can click "Listen"
- [ ] Monitoring page loads

### 3. Verify Audio Streaming
1. Check browser console for WebSocket messages
2. Click "Play" button
3. Adjust volume
4. Watch audio visualizer

- [ ] Console shows "Audio WebSocket connected"
- [ ] Console shows "Subscription confirmed"
- [ ] Audio plays when clicking Play
- [ ] Volume control works
- [ ] Visualizer shows waveform
- [ ] No errors in console

### 4. Verify Transcript (if available)
- [ ] Transcript section visible
- [ ] Text appears as conversation progresses
- [ ] Speaker labels shown (Agent/Customer)

### 5. End Call
1. Hang up the test call
2. Check monitoring interface

- [ ] Call removed from active list
- [ ] "Call ended" event shown
- [ ] Call record updated in database

## Post-Deployment Verification

### 1. Database Check
```bash
rails console

# Check call record
Call.last
# Should show the test call with:
# - vapi_call_id: Twilio CallSid
# - statu: "通話終了"
# - customer_id: if provided
```
- [ ] Call record created
- [ ] Status updated correctly
- [ ] Customer linked (if applicable)

### 2. Cache Check
```bash
rails console

# Check cache (during active call)
Rails.cache.read("call_stream_#{call_sid}")
# Should return hash with call info
```
- [ ] Cache stores call info
- [ ] Cache expires after call ends

### 3. Logs Review
```bash
# Check for errors
grep -i error log/production.log | tail -20

# Check WebSocket activity
grep -i "websocket\|cable" log/production.log | tail -20

# Check Twilio activity
grep -i twilio log/production.log | tail -20
```
- [ ] No critical errors
- [ ] WebSocket connections logged
- [ ] Twilio webhooks logged

## Performance Testing

### 1. Multiple Simultaneous Calls
- [ ] Make 2-3 calls simultaneously
- [ ] All calls appear in monitoring list
- [ ] Can monitor each call independently
- [ ] No performance degradation

### 2. Long Duration Call
- [ ] Make call lasting 5+ minutes
- [ ] Audio continues streaming
- [ ] No disconnections
- [ ] Memory usage stable

### 3. Reconnection Testing
- [ ] Start monitoring a call
- [ ] Refresh browser page
- [ ] Audio resumes after refresh
- [ ] No errors on reconnection

## Troubleshooting

If any checks fail, refer to:
- [ ] `CALL_STREAMING_COMPLETE_SETUP.md` - Full documentation
- [ ] `WEBSOCKET_FLOW_DIAGRAM.md` - Architecture diagram
- [ ] `QUICK_START_CALL_STREAMING.md` - Quick reference
- [ ] Twilio Debugger: https://www.twilio.com/console/debugger
- [ ] Rails logs: `log/production.log`
- [ ] Browser console: F12 → Console tab

## Common Issues

### Issue: "WebSocket connection failed"
**Check:**
- [ ] Redis is running
- [ ] ActionCable URL matches domain
- [ ] SSL certificate valid
- [ ] Firewall allows WebSocket

### Issue: "No audio playing"
**Check:**
- [ ] Browser console for errors
- [ ] WebSocket subscription confirmed
- [ ] Audio format supported by browser
- [ ] Volume not muted

### Issue: "Call not appearing in list"
**Check:**
- [ ] TwiML App configured correctly
- [ ] Phone number linked to TwiML App
- [ ] Call record created in database
- [ ] Cache storing call info

### Issue: "Twilio not connecting"
**Check:**
- [ ] Webhook URL correct in Twilio
- [ ] Server accessible from internet
- [ ] SSL certificate valid
- [ ] No firewall blocking Twilio

## Success Criteria

✅ **Ready for Production When:**
- [ ] All pre-deployment checks pass
- [ ] All development tests pass
- [ ] Twilio configuration complete
- [ ] Production deployment successful
- [ ] Live testing successful
- [ ] No errors in logs
- [ ] Performance acceptable
- [ ] Team trained on usage

## Sign-Off

- [ ] Developer tested: _________________ Date: _______
- [ ] QA tested: _________________ Date: _______
- [ ] Production deployed: _________________ Date: _______
- [ ] Stakeholder approved: _________________ Date: _______

---

**Notes:**
- Keep this checklist for future deployments
- Update if you find additional steps needed
- Document any issues encountered and solutions

**Estimated Time:**
- Development testing: 15 minutes
- Twilio configuration: 10 minutes
- Production deployment: 30 minutes
- Live testing: 15 minutes
- **Total: ~70 minutes**

Good luck with your deployment! 🚀

