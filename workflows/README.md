# n8n Workflows for Automated Calling System

This folder contains n8n workflow configurations for the automated calling system using Vapi, Twilio, and your Rails API.

## Workflows Included

### 1. `automated-calling-workflow.json`
Main workflow that:
- Gets customer phone numbers from your API
- Makes automated calls using Vapi
- Records the calls
- Stores recordings back to your database
- Updates call status

### 2. `transfer-workflow.json`
Handles call transfers to human consultants when customers request them.

## Setup Instructions

### Prerequisites
- n8n instance running
- Vapi account with API key
- Twilio account with phone number
- Your Rails API running

### Configuration Steps

1. **Import Workflows**
   - Copy the JSON files into your n8n instance
   - Update the API endpoints and credentials

2. **Configure API Keys**
   - Set your Vapi API key
   - Set your Twilio credentials
   - Set your Rails API key

3. **Update Endpoints**
   - Replace `https://your-app.com` with your actual domain
   - Update phone numbers and consultant details

4. **Test Workflows**
   - Start with small batches
   - Monitor logs and results
   - Scale up once working properly

## API Endpoints Required

Your Rails app needs these endpoints:

```
GET /api/v1/customers - Get customer list
POST /api/v1/calls/:id/recording - Store call recording
PATCH /api/v1/calls/:id - Update call status
POST /notifications - Send FCM notifications
```

## Environment Variables

Set these in your n8n environment:

```
VAPI_API_KEY=your_vapi_key
TWILIO_ACCOUNT_SID=your_twilio_sid
TWILIO_AUTH_TOKEN=your_twilio_token
RAILS_API_KEY=your_rails_api_key
CONSULTANT_PHONE=+1234567890
```

## Monitoring

- Check n8n execution logs
- Monitor Vapi call logs
- Review Twilio call records
- Check your Rails database for updated records

## Troubleshooting

- Verify API keys are correct
- Check webhook URLs are accessible
- Ensure phone numbers are in correct format
- Monitor rate limits on all services
