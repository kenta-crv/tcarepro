import requests
import time

headers = {"content-type": "application/json"}
inquiry_get = requests.get("http://localhost:3000" + "/api/v1/inquiry?id=" + str(7),headers=headers)
time.sleep(3)
inquiry_data = inquiry_get.json()
print(inquiry_get)