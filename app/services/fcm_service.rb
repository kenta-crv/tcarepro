require 'googleauth'

class FCMService

SERVICE_ACCOUNT_JSON = Rails.root.join('config/smart-edee0-firebase-adminsdk-m74sr-92f564d81e.json')

def self.get_access_token
scope = ['https://www.googleapis.com/auth/firebase.messaging']

authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
json_key_io: File.open(SERVICE_ACCOUNT_JSON),
scope: scope
)

authorizer.fetch_access_token!['access_token']
end
end