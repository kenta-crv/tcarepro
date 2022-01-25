import requests
import json


base = "http://127.0.0.1:5000"
url = base  + "/api/v1/contact"


to_url = "https://ri-plus.jp/"
to_company = "Ri-Plus" 
to_tel = "0662058008"
json_data = {
		"from_company": "会社名",
		"person": "担当者名",
		"kana": "タントウシャ",
		"post": "6888890",
		"address": "大阪府大阪市中央",
		"age": 25,
		"title": "問い合わせ",
		"from_url": "https://www.hirayama-g.com/",
		"from_tel": "09000909909",
		"from_mail": "hirayama@gmail.com",
		"content": "問い合わせ内容",
		"to_company": to_company ,
		"to_url": to_url,
		"to_tel": to_company,
		"to_mail": "hirayama-2@gmail.com"
}    

#POST送信
response = requests.post(
    url,
    data = json.dumps(json_data)    #dataを指定する
    )

res_data = response.json()
print(res_data)