# Twilio Live Call Transcription Setup Guide

This guide explains how to configure Twilio to enable live call transcription with our application.

## Prerequisites

- A Twilio account with API access
- Your Twilio phone number(s) configured
- Access to the Twilio console
- Google Cloud Platform account with Speech-to-Text API enabled
- Google Cloud credentials configured

## Configuration Steps

### 1. Set Up Google Cloud Speech-to-Text

1. Create a Google Cloud Platform (GCP) project or use an existing one
2. Enable the Speech-to-Text API for your project
3. Create a service account with access to the Speech-to-Text API
4. Download the service account key file (JSON)
5. Set the environment variable for your application:
   ```
   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/your/service-account-key.json"
   ```

### 2. Configure Your Twilio Number

1. Log in to your [Twilio Console](https://www.twilio.com/console)
2. Navigate to "Phone Numbers" > "Manage" > "Active Numbers"
3. Select the phone number you want to use for live transcription
4. Under "Voice & Fax" section, set the following:
   - When a call comes in: "Webhook"
   - URL: `https://tcare.pro/twilio/voice`
   - HTTP Method: "POST"
5. Under "Status Callback URL", set:
   - URL: `https://tcare.pro/twilio/status`
   - HTTP Method: "POST"
6. Save your changes

### 3. Install Required Gems

Make sure your application has the following gems installed:

```ruby
# Gemfile
gem 'twilio-ruby'
gem 'google-cloud-speech'
```

Run `bundle install` to install these gems.

### 4. Testing the Setup

1. Make a test call to your Twilio number
2. Visit the live call monitoring interface at:
   ```
   https://tcare.pro/calls_monitoring
   ```
3. You should see the call appear in the list and be able to listen to it and see the live transcript

### 5. Troubleshooting

#### No Audio Stream

- Verify that your Twilio number is correctly configured with the webhook
- Check that the webhook URL is correct and accessible from the internet
- Ensure your server allows WebSocket connections

#### No Transcription

- Check that Google Cloud Speech-to-Text API is enabled
- Verify that your service account has the correct permissions
- Ensure the `GOOGLE_APPLICATION_CREDENTIALS` environment variable is set correctly
- Check your server logs for any errors related to the Speech-to-Text service

#### Connection Issues

- Check your server logs for WebSocket connection errors
- Verify that your server allows WebSocket connections
- Ensure your SSL certificate is valid (Twilio requires HTTPS)

### 6. Additional Configuration Options

#### Speaker Diarization

To enable speaker identification in transcriptions, update the `streaming_config` in `speech_to_text_service.rb`:

```ruby
@streaming_config = {
  config: {
    encoding: :MULAW,
    sample_rate_hertz: 8000,
    language_code: "en-US",
    enable_automatic_punctuation: true,
    use_enhanced: true,
    model: "phone_call",
    diarization_config: {
      enable_speaker_diarization: true,
      min_speaker_count: 2,
      max_speaker_count: 2
    }
  },
  interim_results: true
}
```

#### Multi-language Support

To support multiple languages, update the `language_code` parameter in the configuration:

```ruby
language_code: "ja-JP" # For Japanese
```

Or for auto-language detection:

```ruby
language_code: "en-US",
alternative_language_codes: ["ja-JP", "zh-CN"]
```

## Additional Resources

- [Twilio Media Streams Documentation](https://www.twilio.com/docs/voice/twiml/stream)
- [Google Cloud Speech-to-Text Documentation](https://cloud.google.com/speech-to-text/docs)
- [WebSocket API Documentation](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API)
