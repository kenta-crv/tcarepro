from sys import flags
from inquery_automation.browser import Browser
from os import access
from flask import Flask, render_template, request, redirect, url_for,jsonify
import time
import threading
from datetime import datetime
import json
from json import dumps, loads
from flask import Flask, jsonify, request
from marshmallow import Schema, fields, ValidationError

from inquery_automation.contact_info import ContactInfoSchema,ContactInfo
from inquery_automation.auto_inquery import AutoInquery
app = Flask(__name__)

@app.route('/api/v1/contact', methods=['POST'])
def contact():

    request_data = json.loads(request.data.decode('utf-8'))
    schema = ContactInfoSchema()
    try:
        # ポストされたjsonをContactInfoSchemaとしてロードする
        contact_info_json = schema.load(request_data)
    except ValidationError as err:
        # ロードできない場合はエラーを返却
        return jsonify(err.messages), 400
    # 問い合わせ機能の実行
    contact_info = ContactInfo(contact_info_json=contact_info_json)
    auto_inquery = AutoInquery()
    result_json = auto_inquery.auto_inquery(contact_info=contact_info)
    del auto_inquery
    return result_json, 200


if __name__ == '__main__':

    app.run()