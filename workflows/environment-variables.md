# Environment Variables for n8n Workflows

Set these environment variables in your n8n instance:

## Required Variables

### Vapi Configuration
```
VAPI_API_KEY=your_vapi_api_key_here
VAPI_PHONE_NUMBER_ID=your_vapi_phone_number_id
VAPI_ASSISTANT_ID=your_vapi_assistant_id
```

### Twilio Configuration
```
TWILIO_ACCOUNT_SID=your_twilio_account_sid
TWILIO_AUTH_TOKEN=your_twilio_auth_token
```

### Rails API Configuration
```
RAILS_API_KEY=your_rails_api_key_here
```

### Consultant Configuration
```
CONSULTANT_PHONE=+1234567890
CONSULTANT_DEVICE_TOKEN=your_consultant_fcm_token
```

## How to Set Environment Variables

### In n8n Cloud
1. Go to Settings → Environment Variables
2. Add each variable with its value
3. Save the configuration

### In Self-hosted n8n
1. Add to your `.env` file:
```bash
VAPI_API_KEY=your_vapi_api_key_here
VAPI_PHONE_NUMBER_ID=your_vapi_phone_number_id
VAPI_ASSISTANT_ID=your_vapi_assistant_id
TWILIO_ACCOUNT_SID=your_twilio_account_sid
TWILIO_AUTH_TOKEN=your_twilio_auth_token
RAILS_API_KEY=your_rails_api_key_here
CONSULTANT_PHONE=+1234567890
CONSULTANT_DEVICE_TOKEN=your_consultant_fcm_token
```

2. Restart n8n

## Getting Your API Keys

### Vapi API Key
1. Log into Vapi dashboard
2. Go to Settings → API Keys
3. Create a new API key
4. Copy the key

### Vapi Phone Number ID
1. In Vapi dashboard, go to Phone Numbers
2. Copy the ID of your phone number

### Vapi Assistant ID
1. In Vapi dashboard, go to Assistants
2. Copy the ID of your assistant

### Twilio Credentials
1. Log into Twilio Console
2. Go to Account → API Keys & Tokens
3. Copy Account SID and Auth Token

### Rails API Key
1. Generate a secure API key in your Rails app
2. Add it to your environment variables

### Consultant Phone
1. Use the phone number where consultants will receive calls
2. Format: +1234567890 (with country code)

### Consultant Device Token
1. Get the FCM token from consultant's mobile device
2. This is used for push notifications
