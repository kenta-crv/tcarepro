# API Endpoint for Call Recording Storage

## Endpoint
```
POST /api/v1/calls
```

## Request Body
```json
{
  "customer_id": 1,
  "recording_url": "https://storage.vapi.ai/recording.wav",
  "recording_duration": 120,
  "vapi_call_id": "call_1234567890",
  "comment": "Automated call via Vapi"
}
```

## Required Fields
- `customer_id` (integer) - ID of the customer
- `recording_url` (string) - URL to the call recording
- `recording_duration` (integer) - Duration in seconds
- `vapi_call_id` (string) - Unique Vapi call identifier

## Optional Fields
- `statu` (string) - Call status (default: "自動コール完了")
- `comment` (string) - Call notes (default: "Automated call via Vapi")

## Response
### Success (201)
```json
{
  "status": "SUCCESS",
  "call_id": 123,
  "message": "Call record stored successfully",
  "recording_url": "https://storage.vapi.ai/recording.wav"
}
```

### Error (404)
```json
{
  "status": "ERROR",
  "message": "Customer not found"
}
```

### Error (422)
```json
{
  "status": "ERROR",
  "message": "Validation failed",
  "errors": ["Recording url can't be blank"]
}
```

## n8n Workflow Integration

### HTTP Request Node Configuration:
- **URL:** `https://tcare.pro/api/v1/calls`
- **Method:** POST
- **Headers:** 
  - `Content-Type: application/json`
- **Body:** Use the JSON structure above with n8n expressions

### Example n8n Body:
```json
{
  "customer_id": "{{$json.customer_id}}",
  "recording_url": "{{$json.recording_url}}",
  "recording_duration": "{{$json.recording_duration}}",
  "vapi_call_id": "{{$json.vapi_call_id}}",
  "comment": "Automated call via Vapi - {{$json.call_end_reason}}"
}
```

## Database Fields Added
- `recording_url` (string) - URL to call recording
- `recording_duration` (integer) - Duration in seconds  
- `vapi_call_id` (string) - Vapi call identifier
- `recording_file_path` (string) - Local file path (optional)
- `transcript` (text) - Call transcript (optional)
- `cost` (decimal) - Call cost (optional)

## UI Integration
The recording URL will be displayed in the customer call history with:
- Audio player controls
- Duration display
- Direct link to recording
