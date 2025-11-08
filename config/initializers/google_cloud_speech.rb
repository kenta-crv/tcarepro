# Set Google Cloud Speech API key from environment variable
# The API key should be set in your environment or .env file
# DO NOT hardcode API keys in the source code
ENV["GOOGLE_API_KEY"] ||= ENV["GOOGLE_SPEECH_API_KEY"]