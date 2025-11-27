# Google Cloud Credentials

This directory contains the Google Cloud service account credentials for Speech-to-Text API.

## File
- `google-speech-credentials.json` - Service account credentials

## Security
⚠️ **IMPORTANT**: These files are protected by `.gitignore` and should NEVER be committed to version control.

## Environment Variable
Make sure your `.env` file contains:
```
GOOGLE_APPLICATION_CREDENTIALS="config/credentials/google-speech-credentials.json"
```

## Usage
The credentials are automatically loaded by the `google-cloud-speech` gem when the environment variable is set.

