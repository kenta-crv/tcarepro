import json
from marshmallow import Schema, fields

class ContactInfoSchema(Schema):
	"""
	送信側情報
		会社名:
			カラム名:from_company 
			型:String
			必須:required
		担当者名:
			カラム名:person 
			型:String
			必須:required
		カナ:
			カラム名:kana 
			型:String
			必須:required    
		郵便番号:
			カラム名:post 
			型:Integer
			必須:required  
		住所:
			カラム名:address 
			型:String
			必須:required  
		url:
			カラム名:url 
			型:String
			必須:required  
		age:
			カラム名:age 
			型:Integer
			必須:required  
		title:
			カラム名:title 
			型:String
			必須:required  
		電話番号:
			カラム名:from_tel 
			型:String
			必須:required
		メールアドレス:
			カラム名:from_mail 
			型:String
			必須:required
		送信内容:
			カラム名:content 
			型:String
			必須:required
	送信先情報
		会社名:
			カラム名:to_company 
			型:String
			必須:required
		ホームページ:
			カラム名:url 
			型:String
			必須:required
		電話番号:
			カラム名:to_tel 
			型:String
			必須:required
		メールアドレス:
			カラム名:to_mail
			型:String
			必須:required
	"""
	from_company = fields.String(required=True)
	person = fields.String(required=True)
	kana = fields.String(required=True)
	post = fields.Integer(required=True)
	address = fields.String(required=True)
	age = fields.Integer(required=True)
	title = fields.String(required=True)
	from_url = fields.String(required=True)
	from_tel = fields.String(required=True)
	from_mail = fields.String(required=True)
	content = fields.String(required=True)
	to_company = fields.String(required=True)
	to_url = fields.String(required=True)
	to_tel = fields.String(required=True)
	to_mail = fields.String(required=True)

class ContactInfo:
	"""
	送信側情報
		会社名:
			カラム名:from_company 
			型:String
			必須:required
		担当者名:
			カラム名:person 
			型:String
			必須:required
		カナ:
			カラム名:kana 
			型:String
			必須:required    
		郵便番号:
			カラム名:post 
			型:Integer
			必須:required  
		住所:
			カラム名:address 
			型:String
			必須:required  
		url:
			カラム名:url 
			型:String
			必須:required  
		age:
			カラム名:age 
			型:Integer
			必須:required  
		title:
			カラム名:title 
			型:String
			必須:required  
		電話番号:
			カラム名:from_tel 
			型:String
			必須:required
		メールアドレス:
			カラム名:from_mail 
			型:String
			必須:required
		送信内容:
			カラム名:content 
			型:String
			必須:required
	送信先情報
		会社名:
			カラム名:to_company 
			型:String
			必須:required
		ホームページ:
			カラム名:url 
			型:String
			必須:required
		電話番号:
			カラム名:to_tel 
			型:String
			必須:required
		メールアドレス:
			カラム名:to_mail
			型:String
			必須:required
	"""

	def __init__(self,contact_info_json:json):
		self.from_company = contact_info_json["from_company"]
		self.person = contact_info_json["person"]
		self.kana = contact_info_json["kana"]
		self.post = contact_info_json["post"]
		self.address = contact_info_json["address"]
		self.age = contact_info_json["age"]
		self.title = contact_info_json["title"]
		self.from_url = contact_info_json["from_url"]
		self.from_tel = contact_info_json["from_tel"]
		self.from_mail = contact_info_json["from_mail"]
		self.content = contact_info_json["content"]
		self.to_company = contact_info_json["to_company"]
		self.to_url = contact_info_json["to_url"]
		self.to_tel = contact_info_json["to_tel"]
		self.to_mail = contact_info_json["to_mail"]


	
