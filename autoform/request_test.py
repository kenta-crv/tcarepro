import requests
import json

server_domain = "http://localhost:3000/"

headers = {"content-type": "application/json"}
data = {"title":"message","message":"メッセージテスト","status":"notify"}
message_post = requests.post(server_domain + "/api/v1/pycall",data=json.dumps(data),headers=headers)
print(message_post)
message = message_post.json()
print(message)