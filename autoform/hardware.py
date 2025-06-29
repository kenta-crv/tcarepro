from selenium import webdriver
from selenium.webdriver import ChromeOptions
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.chrome import service as fs
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.support.select import Select
from selenium.webdriver.chrome.options import Options
from selenium.common.exceptions import NoAlertPresentException, UnexpectedAlertPresentException
import requests
from bs4 import BeautifulSoup
import time
import sys
import traceback

#Changed
import chromedriver_binary

options = webdriver.ChromeOptions()
options.add_argument('--headless')
#options.binary_location = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
start = time.perf_counter()
serv = Service(ChromeDriverManager().install())
#serv = Service(executable_path='/okuyamakenta/python')

class Place_enter():
    def __init__(self,url,formdata):

        #URL
        self.endpoint = url

        #idデータ
        self.company = ''
        self.company_kana = ''
        self.manager = ''
        self.manager_kana = ''
        self.manager_first = ''
        self.manager_last = ''
        self.manager_first_kana = ''
        self.manager_last_kana = ''
        self.pref = ''
        self.phone = ''
        self.phone0 = ''
        self.phone1 = ''
        self.phone2 = ''
        self.fax = ''
        self.address = ''
        self.address_pref = ''
        self.address_city = ''
        self.address_thin = ''
        self.zip = ''
        self.mail = ''
        self.mail_c = ''
        self.url = ''
        self.subjects = ''
        self.body = ''
        self.namelist = ''
        self.kiyakucheck = {} #規約
        self.response_contact = [] #れすぽんす方式
        self.industry = []
        self.subjects_radio_badge = False

        self.formdata = formdata

        self.iframe_mode = False

        self.radio = []
        self.chk = []


        #BS4データ
        req = requests.get(self.endpoint)
        req.encoding = req.apparent_encoding  # エンコーディングを自動的に推測して設定
        self.pot = BeautifulSoup(req.text, "lxml")
        self.form = self.target_form()
        if not self.form:
            print("No valid form found!")
            return
        tables = self.target_table()

        #formスキャン
        if self.form == 0:
            print("form is not. iframe???")
            if self.pot.find('iframe'):
                driver = webdriver.Chrome(service=serv,options=options)
                driver.get(self.endpoint)
                iframe = driver.find_element(By.TAG_NAME,'iframe')
                driver.switch_to.frame(iframe)
                source = BeautifulSoup(driver.page_source, "lxml").prettify()
                self.pot = BeautifulSoup(source, "lxml")
                self.form = self.target_form()
                driver.close()
                self.iframe_mode = True
            else:
                print('false')

        def extract_input_data(element):
            data = {}
            input_type = element.get('type')
            if input_type in ['radio', 'checkbox']:
                data = {'object': 'input', 'name': element.get('name'), 'type': input_type, 'value': element.get('value')}
            elif input_type == 'hidden':
                data = {'object': 'hidden'}
            else:
                data = {'object': 'input', 'name': element.get('name'), 'type': input_type, 'value': element.get('value')}
                placeholder = element.get('placeholder')
                if placeholder:
                    data['placeholder'] = placeholder

            return data

        def extract_textarea_data(element):
            data = {'object': 'textarea', 'name': element.get('name')}
            if 'class' in element.attrs:
                data['class'] = element.get('class')
            return data

        def extract_select_data(element):
            data_list = []
            data = {'object': 'select', 'name': element.get('name')}
            if 'class' in element.attrs:
                data['class'] = element.get('class')
            data_list.append(data)
            for option in element.find_all('option'):
                option_data = {'object': 'option', 'link': element.get('name'), 'value': option.get('value')}
                if 'class' in option.attrs:
                    option_data['class'] = option.get('class')
                data_list.append(option_data)
            print("extract_select_data" + str(data_list))
            return data_list

        def extract_elements_from_tags(tag, element_type):
            data_list = []
            for parent in self.form.find_all(tag):
                for child in parent.find_all(element_type):
                    if element_type == 'input':
                        data_list.append(extract_input_data(child))
                    elif element_type == 'textarea':
                        data_list.append(extract_textarea_data(child))
                    elif element_type == 'select':
                        data_list.extend(extract_select_data(child))
            print("extract_elements_from_tags: " + str(data_list))
            return data_list

        # 以下の部分で上記の関数を使用する
        def extract_elements_from_dtdl(parent_element):
            data_list = []
            dt_text = parent_element.find('dt').get_text(strip=True) if parent_element.find('dt') else None

            for child in parent_element.find_all(['input', 'textarea', 'select']):
                if child.name == 'input':
                    data = extract_input_data(child)
                elif child.name == 'textarea':
                    data = extract_textarea_data(child)
                elif child.name == 'select':
                    # select要素の場合、個々の option は extract_select_data() 内で処理するのでここではスキップ
                    data_list.extend(extract_select_data(child))
                    continue

                if dt_text:
                    data['label'] = dt_text
                data_list.append(data)

            print("extract_elements_from_dtdl: " + str(data_list))
            return data_list

        def find_and_add_to_namelist(tables):
            data_dict = {}  # name をキーとしてデータを保存（後の値が上書きされる）

            for row in tables.find_all('tr', recursive=False):  # ネストされた tr を無視
                th = row.find('th')  # `th` がある場合はそれを優先
                label_text = th.get_text(strip=True) if th else ""

                for elem_type in ['input', 'textarea', 'select']:
                    for col in row.find_all('td', recursive=False):  # ネストされた `td` を無視
                        elem = col.find(elem_type)
                        if elem and 'name' in elem.attrs:
                            name = elem['name']

                            # `label` の取得方法を調整（th > td の順で取得）
                            text_from_td = col.get_text(strip=True)
                            final_label = label_text if label_text else text_from_td

                            data = {
                                'object': elem_type,
                                'name': name,
                                'label': final_label,  # より近い `th` のテキストを使用
                            }

                            if elem_type == 'input':
                                data['type'] = elem.get('type', 'text')  # `None` を防ぐ
                                data['value'] = elem.get('value', '')  # `None` を防ぐ

                            # **既に `name` が存在する場合、後の値で上書き**
                            data_dict[name] = data

                            print(f"Added/Updated: {data}")

            # **辞書の値だけをリストに変換**
            data_list = list(data_dict.values())
            return data_list




        namelist = []

        if self.target_table() == 0 and self.target_dtdl() == 0:#formだが、dtdl なし
            print('dtdl not found')

            for tag in ['span', 'div']:
                namelist.extend(extract_elements_from_tags(tag, 'input'))
                namelist.extend(extract_elements_from_tags(tag, 'textarea'))
                namelist.extend(extract_elements_from_tags(tag, 'select'))
        elif self.target_table() == 0:#formでかつ、dtdlあり
            print('Read')
            for dl in self.target_dtdl():
                namelist.extend(extract_elements_from_dtdl(dl))
        else:#table
            # Search for keywords in <td> and add to namelist
            for table in tables:
                namelist.extend(find_and_add_to_namelist(table))


        self.namelist = namelist
        self.logicer(self.namelist)
        print("namelist" + str(self.namelist))


    def target_form(self):
        for form in self.pot.find_all('form'):
            class_name = form.get('class', '')
            id_name = form.get('id', '')

            if 'search' not in class_name and 'search' not in id_name:
                return form
        return 0

    def target_table(self):
        if self.form.find('table'):
            print('tableを見つけました')
            return self.form.find_all('table')
        else:
            return 0

    def target_dtdl(self):
        if self.form.find('dl'):
            print('dtdlを見つけました')
            return self.form.find_all('dl')
        else:
            return 0

    def logicer(self, lists):
        for olist in lists:
            label = olist.get('label', '')
            name = olist.get('name', '')
            if olist["object"] == "input":
                self.subjects = olist["name"]
            if olist["object"] == "textarea":
                self.subjects = olist["name"]

            print("label: " + label)
            print("name: " + name)

            if name:
                if olist["object"] == "input":
                    if "会社" in name or "社名" in name or "店名" in name or "社" in name:
                        self.company = olist["name"]
                    elif "会社ふりがな" in name or "会社フリガナ" in name:
                        self.company_kana = olist["name"]
                    elif "名前" in name or "担当者" in name or "氏名" in name:
                        self.manager = olist["name"]
                    elif "ふりがな" in name or "フリガナ" in name:
                        self.manager_kana = olist["name"]
                    elif "郵便番号" in name:
                        self.zip = olist["name"]
                    elif "住所" in name:
                        self.address = olist["name"]
                    elif "都道府県" in name:
                        self.pref = olist["name"]
                    elif "市区町村" in name:
                        self.address_city = olist["name"]
                    elif "番地" in name:
                        self.address_thin = olist["name"]
                    elif "電話番号" in name:
                        self.phone = olist["name"]
                    elif ("メールアドレス" in name or "mail" in name) and "確認" not in name:
                        if(self.mail):
                            self.mail_c = olist["name"]
                        else:
                            self.mail = olist["name"]
                    elif ("メールアドレス" in name or "mail" in name) and "確認" in name:
                        self.mail_c = olist["name"]
                    elif "用件" in name or "お問い合わせ" in name or "本文" in name or "内容" in name:
                        self.subjects = olist["name"]
                    elif olist["type"] == "radio":
                        self.radio.append({"radioname": olist["name"], "value": olist["value"]})
                    elif olist["type"] == "checkbox":
                        self.chk.append({"checkname": olist["name"], "value": olist["value"]})
                elif olist["object"] == "textarea":
                    if "用件" in name or "お問い合わせ" in name or "本文" in name or "内容" in name:
                        self.body = olist["name"]
                elif olist["object"] == "select":
                    if "都道府県" in name:
                        self.pref = olist["name"]
                    if "用件" in name or "お問い合わせ" in name or "本文" in name or "内容" in name:
                        self.subjects = olist["name"]

            if label:
                if olist["object"] == "input":
                    if "会社" in label or "社名" in label or "店名" in label or "社" in label:
                        self.company = olist["name"]
                    elif "会社ふりがな" in label or "会社フリガナ" in label:
                        self.company_kana = olist["name"]
                    elif "名前" in label or "担当者" in label or "氏名" in label:
                        self.manager = olist["name"]
                    elif "ふりがな" in label or "フリガナ" in label:
                        self.manager_kana = olist["name"]
                    elif "郵便番号" in label:
                        self.zip = olist["name"]
                    elif "住所" in label:
                        self.address = olist["name"]
                    elif "都道府県" in label:
                        self.pref = olist["name"]
                    elif "市区町村" in label:
                        self.address_city = olist["name"]
                    elif "番地" in label:
                        self.address_thin = olist["name"]
                    elif "電話番号" in label:
                        self.phone = olist["name"]
                    elif ("メールアドレス" in label or "mail" in label) and "確認" not in label:
                        if(self.mail):
                            self.mail_c = olist["name"]
                        else:
                            self.mail = olist["name"]
                        self.mail = olist["name"]
                    elif ("メールアドレス" in label or "mail" in label) and "確認" in label:
                        self.mail_c = olist["name"]
                    elif "用件" in label or "お問い合わせ" in label or "本文" in label or "内容" in label:
                        self.subjects = olist["name"]
                    elif olist["type"] == "radio":
                        self.radio.append({"radioname": olist["name"], "value": olist["value"]})
                    elif olist["type"] == "checkbox":
                        self.chk.append({"checkname": olist["name"], "value": olist["value"]})
                elif olist["object"] == "textarea":
                    if "用件" in label or "お問い合わせ" in label or "本文" in label or "内容" in label:
                        self.body = olist["name"]
                elif olist["object"] == "select":
                    if "都道府県" in label:
                        self.pref = olist["name"]
                    if "用件" in label or "お問い合わせ" in label or "本文" in label or "内容" in label:
                        self.subjects = olist["name"]


    def go_selenium(self):
        # webdriver.Chrome(...) を呼び出して、あらかじめ用意されたサービスオブジェクト（serv）とオプション（ヘッドレスなどの設定）を利用してブラウザを起動
        driver = webdriver.Chrome(service=serv,options=options)
        driver.get(self.endpoint)
        time.sleep(3)

        def input_text_field(driver, field_name, value):
            """テキストフィールドに値を入力するための関数"""
            print(f"Field Name: {field_name}, Value: {value}")
            if field_name and value:
                try:
                    driver.find_element(By.NAME, field_name).send_keys(value)
                except Exception as e:
                    print(f"Error inputting into {field_name}: {e}")

        def select_radio_button(driver, radio_name):
            """ラジオボタンを選択するための関数"""
            try:
                radian = driver.find_elements(By.XPATH, f"//input[@type='radio' and @name='{radio_name}']")
                if radian:
                    if not radian[0].is_selected():
                        radian[0].click()
            except Exception as e:
                print(f"Error clicking radio button {radio_name}: {e}")

        def select_checkbox(driver, checkbox_name):
            """チェックボックスを選択するための関数"""
            try:
                checkboxes = driver.find_elements(By.XPATH, f"//input[@type='checkbox' and @name='{checkbox_name}']")
                for checkbox in checkboxes:
                    if not checkbox.is_selected():
                        checkbox.click()
            except Exception as e:
                print(f"Error clicking checkbox {checkbox_name}: {e}")

        
        def fill_all_fields(driver, formdata):
            """
            すべての <input> フィールドに formdata['company'] を入力し、
            すべての <textarea> フィールドに formdata['subjects'] を入力する。
            """
            try:
                # すべての <input> タグに `company` を入力
                input_fields = driver.find_elements(By.TAG_NAME, "input")
                for input_field in input_fields:
                    input_type = input_field.get_attribute("type")

                    # `hidden` や `submit` タイプのものはスキップ
                    if input_type not in ["hidden", "submit", "button", "reset"]:
                        input_field.clear()
                        input_field.send_keys(formdata['company'])
                        print(f"Filled input field: {input_field.get_attribute('name')} with {formdata['company']}")

                # すべての <textarea> タグに `subjects` を入力
                textarea_fields = driver.find_elements(By.TAG_NAME, "textarea")
                for textarea in textarea_fields:
                    textarea.clear()
                    textarea.send_keys(formdata['subjects'])
                    print(f"Filled textarea field: {textarea.get_attribute('name')} with {formdata['subjects']}")

            except Exception as e:
                print(f"Error filling fields: {e}")

        # Webページ内に別のWebページを埋め込む機能（iframe）が使われている場合、iframe内に移動する
        if self.iframe_mode == True:
            try:
                iframe = driver.find_element(By.TAG_NAME,'iframe')
            except Exception as e:
                print("iframe not found")
                print(e)
            driver.switch_to.frame(iframe)
            fill_all_fields(driver, self.formdata)
            # bootioから送信されたフォーム内容を入力
            input_text_field(driver, self.company, self.formdata['company'])
            input_text_field(driver, self.company_kana, self.formdata['company_kana'])
            input_text_field(driver, self.manager, self.formdata['manager'])
            input_text_field(driver, self.manager_kana, self.formdata['manager_kana'])
            input_text_field(driver, self.phone, self.formdata['phone'])
            input_text_field(driver, self.fax, self.formdata['fax'])
            input_text_field(driver, self.address, self.formdata['address'])
            input_text_field(driver, self.mail, self.formdata['mail'])
            input_text_field(driver, self.mail_c, self.formdata['mail'])

            for radio_info in self.radio:
                select_radio_button(driver, radio_info['radioname'])

            for checkbox_info in self.chk:
                select_checkbox(driver, checkbox_info['checkname'])


            #分割用電話番号
            # 怪しい
            # <input type="text" name="phone_part1" placeholder="市外局番">
            # <input type="text" name="phone_part2" placeholder="市内局番">
            # <input type="text" name="phone_part3" placeholder="加入者番号">
            # ここで、self.phone0 に "phone_part1" という値が設定されていると仮定します。
            # コード内の
            # python
            # driver.find_element(By.NAME, self.phone0)
            # は、実際には
            # python
            # driver.find_element(By.NAME, "phone_part1")
            try:
                if self.phone0 != '' and self.phone1 != '' and self.phone2 != '':
                    phonesplit = self.formdata['phone'].split('-')
                    driver.find_element(By.NAME,self.phone0).send_keys(phonesplit[0])
                    driver.find_element(By.NAME,self.phone1).send_keys(phonesplit[1])
                    driver.find_element(By.NAME,self.phone2).send_keys(phonesplit[2])
            except Exception as e:
                print("Error: Failed to submit form")
                print(e)

            # 指定のAPIにアクセスして、住所に基づいた郵便番号を取得し、入力
            if self.zip != '':
                r = requests.get("https://api.excelapi.org/post/zipcode?address=" + self.formdata['address'])
                postman = r.text
                try:
                    driver.find_element(By.NAME,self.zip).send_keys(postman[:3]+ "-" + postman[3:])
                except Exception as e:
                    print("Error: Failed to submit form")
                    print(e)

            # 都道府県・市区町村の自動選択
            if self.pref != '':
                pref_data = ''
                pref = [
                    "北海道","青森県","岩手県","宮城県","秋田県","山形県","福島 県",
                    "茨城県","栃木県","群馬県","埼玉県","千葉県","東京都","神奈 川県",
                    "新潟県","富山県","石川県","福井県","山梨県","長野県","岐阜 県",
                    "静岡県","愛知県","三重県","滋賀県","京都府","大阪府","兵庫 県",
                    "奈良県","和歌山県","鳥取県","島根県","岡山県","広島県","山 口県",
                    "徳島県","香川県","愛媛県","高知県","福岡県","佐賀県","長崎 県",
                    "熊本県","大分県","宮崎県","鹿児島県","沖縄県"
                ]

                address = self.formdata['address']

                try:
                    element = driver.find_element(By.NAME, self.pref)
                    for p in pref:
                        if p in address:
                            if element.tag_name == "select":
                                s = Select(element)
                                s.select_by_visible_text(p)
                                pref_data = p
                            else:
                                pref_data = p

                        
                    # Geo API を利用して市区町村・町名を取得し、入力欄にセット
                    r = requests.get("https://geoapi.heartrails.com/api/json?method=getTowns&prefecture=" + pref_data)
                    cityjs = r.json()
                    city = cityjs["response"]["location"]
                    print("cityjs")
                    for c in city:
                        if c["city"] in address and c["town"] in address:
                            driver.find_element(By.NAME,self.address_city).send_keys(c["city"])
                            driver.find_element(By.NAME,self.address_thin).send_keys(c["town"])

                except Exception as e:
                    print("Error: Failed to submit form")
                    print(e)

            # 用件・本文の入力
            try:
                if self.subjects != '':
                    matching = False
                    if self.subjects_radio_badge == True:
                        print(self.chk)
                        for c in self.chk:
                            # c['value'] が "お問い合わせ内容" や "お問い合わせ" などの場合に条件を満たす
                            if 'お問い合わせ' in c['value']:
                                # XPath の式 "//input[@name='...']" によって、name 属性が c['name'] と一致し、かつ value 属性が c['value'] と一致する <input> 要素を取得し
                                checking = driver.find_element(By.XPATH,"//input[@name='" + c['checkname']+"' and @value='" + c['value']+"']")
                                if not checking.is_selected():
                                    # driver.execute_script("arguments[0].click();", checking) を用いる理由は、通常の click() メソッドではクリックできない場合や、表示上の問題がある場合に、JavaScript を利用して確実にクリックイベントを発火させるため
                                    driver.execute_script("arguments[0].click();", checking)

                    # 用件（お問い合わせ内容）を入力する処理
                    # 対象がドロップダウン（select 要素）の場合は、候補の中から一致する項目を選択
                    # それ以外の場合は、入力欄に直接入力
                    if driver.find_element(By.NAME,self.subjects).tag_name == 'select':
                        select = Select(driver.find_element(By.NAME,self.subjects))
                        for opt in select.options:
                            if self.formdata['subjects'] == opt:
                                matching = True
                                select.select_by_visible_text(opt)

                        if matching == False:
                            select.select_by_index(len(select.options)-1)

                    else:
                        driver.find_element(By.NAME,self.subjects).send_keys(self.formdata['subjects'])
            except Exception as e:
                print(f"Error encountered: {e}")
                # ここに追加のエラー処理を書くことができます。

            try:
                # フォームの本文欄に、フォームデータから取得した内容を入力
                if self.body != '':
                    driver.find_element(By.NAME,self.body).send_keys(self.formdata['body'])
            except Exception as e:
                print(f"Error encountered: {e}")
                # ここに追加のエラー処理を書くことができます。

            # 複数の候補テキスト（例：「確認」、「送信」）を用いて、該当するボタンを XPath で探索し、見つかり次第クリックします。
            # タイムアウトまで待機する仕組み（WebDriverWait）を用いることで、要素が現れるのを待つ。
            def click_button(driver, button_texts):
                for text in button_texts:
                    xpaths = [
                        f"//button[contains(text(), '{text}')]",
                        f"//input[contains(@value, '{text}')]"
                    ]
                    for xpath in xpaths:
                        try:
                            button = WebDriverWait(driver, 10).until(
                                EC.presence_of_element_located((By.XPATH, xpath))
                            )
                            button.click()
                            return True
                        except:
                            continue
                return False

            try:
                before = driver.title

                # "確認" または "送信" ボタンをクリック
                if click_button(driver, ['確認']):
                    print("Clicked the 'confirm' button")
                elif click_button(driver, ['送信']):
                    print("Clicked the 'submit' button")
                else:
                    print("Error: Could not find either 'confirm' or 'submit' button")
                    driver.close()
                    return 'NG'

                # 送信が成功したかどうかの確認（タイトルの変更を確認）
                time.sleep(3)  # 送信後のページへの移動を待機
                after = driver.title
                page_source = driver.page_source
                if before != after or "ありがとう" in page_source or "完了" in page_source:  # タイトルが変わった場合、送信成功と判断
                    driver.close()
                    return 'OK'
                else:
                    driver.close()
                    print("Error: Failed to submit form")
                    return 'NG'

            except Exception as e:
                print(f"Error: {e}")
                print("submit false")
                driver.close()
                return 'NG'


            """
            ##　規約 プライバシーポリシーチェック
            try:
                print(self.kiyakucheck)
                if self.kiyakucheck != {}:
                    checking = driver.find_element(By.XPATH,"//input[@name='" + self.kiyakucheck['name']+"']")
                    if not checking.is_selected():
                        driver.execute_script("arguments[0].click();", checking)
            except Exception as e:
                print("同意エラー")
                print(e)

            ## 連絡方法
            try:
                if self.response_contact != []:
                    for radioarray in self.response_contact:
                        radian = driver.find_elements(By.XPATH, "//input[@type='radio' and @name='"+ radioarray['name']+"']")
                        for radio in radian:
                            r = radio.get_attribute(("value"))
                            if "どちらでも" in r:
                                radio.click()

            except Exception as e:
                print("押せない")
                print(e)

            try:
                print(self.industry)
                if self.industry != []:
                    for radioarray in self.industry:
                        radian = driver.find_elements(By.XPATH, "//input[@type='radio' and @name='"+ radioarray['name']+"']")
                        for radio in radian:
                            r = radio.get_attribute(("value"))
                            if 'メーカー' in r:
                                driver.execute_script("arguments[0].click();", radio)
            except Exception as e:
                print(traceback.format_exc())

            time.sleep(2)
            """

        else:
            fill_all_fields(driver, self.formdata)
            input_text_field(driver, self.company, self.formdata['company'])
            print("company:"+self.company)
            input_text_field(driver, self.company_kana, self.formdata['company_kana'])
            input_text_field(driver, self.manager, self.formdata['manager'])
            print("manager:"+self.manager)
            input_text_field(driver, self.manager_kana, self.formdata['manager_kana'])
            input_text_field(driver, self.phone, self.formdata['phone'])
            print("phone:"+self.phone)
            input_text_field(driver, self.fax, self.formdata['fax'])
            input_text_field(driver, self.address, self.formdata['address'])
            print("address:"+self.address)
            input_text_field(driver, self.mail, self.formdata['mail'])
            print("mail:"+self.mail)
            input_text_field(driver, self.mail_c, self.formdata['mail'])

            for radio_info in self.radio:
                select_radio_button(driver, radio_info['radioname'])

            for checkbox_info in self.chk:
                select_checkbox(driver, checkbox_info['checkname'])

            #分割用電話番号
            try:
                if self.phone0 != '' and self.phone1 != '' and self.phone2 != '':
                    phonesplit = self.formdata['phone'].split('-')
                    driver.find_element(By.NAME,self.phone0).send_keys(phonesplit[0])
                    driver.find_element(By.NAME,self.phone1).send_keys(phonesplit[1])
                    driver.find_element(By.NAME,self.phone2).send_keys(phonesplit[2])
            except Exception as e:
                print("Error: Failed to submit form")
                print(e)


            try:
                if self.zip != '':
                    r = requests.get("https://api.excelapi.org/post/zipcode?address=" + self.formdata['address'])
                    postman = r.text
                    driver.find_element(By.NAME,self.zip).send_keys(postman[:3]+ "-" + postman[3:])
            except Exception as e:
                print("Error: Failed to submit form")
                print(e)

            try:
                if self.pref != '':
                    pref_data = ''
                    pref = [
                        "北海道","青森県","岩手県","宮城県","秋田県","山形県"," 福島県",
                        "茨城県","栃木県","群馬県","埼玉県","千葉県","東京都"," 神奈川県",
                        "新潟県","富山県","石川県","福井県","山梨県","長野県"," 岐阜県",
                        "静岡県","愛知県","三重県","滋賀県","京都府","大阪府"," 兵庫県",
                        "奈良県","和歌山県","鳥取県","島根県","岡山県","広島県","山口県",
                        "徳島県","香川県","愛媛県","高知県","福岡県","佐賀県"," 長崎県",
                        "熊本県","大分県","宮崎県","鹿児島県","沖縄県"
                    ]

                    address = self.formdata['address']

                    element = driver.find_element(By.NAME, self.pref)
                    for p in pref:
                        if p in address:
                            if element.tag_name == "select":
                                s = Select(element)
                                s.select_by_visible_text(p)
                                pref_data = p
                            else:
                                pref_data = p

                    if self.address_city != '' and  self.address_thin != '':
                        r = requests.get("https://geoapi.heartrails.com/api/json?method=getTowns&prefecture=" + pref_data)
                        cityjs = r.json()
                        city = cityjs["response"]["location"]
                        print("cityjs")
                        for c in city:
                            print(c["city"])
                            if c["city"] in address and c["town"] in address:
                                driver.find_element(By.NAME,self.address_city).send_keys(c["city"])
                                driver.find_element(By.NAME,self.address_thin).send_keys(c["town"])
            except Exception as e:
                print("Error: Failed to submit form")
                print(e)


            try:
                if self.subjects != '':
                    matching = False
                    if self.subjects_radio_badge == True:
                        print(self.chk)
                        for c in self.chk:
                            if 'お問い合わせ' in c['value']:
                                checking = driver.find_element(By.XPATH,"//input[@name='" + c['checkname']+"' and @value='" + c['value']+"']")
                                if not checking.is_selected():
                                    driver.execute_script("arguments[0].click();", checking)

                    if driver.find_element(By.NAME,self.subjects).tag_name == 'select':
                        select = Select(driver.find_element(By.NAME,self.subjects))
                        for opt in select.options:
                            if self.formdata['subjects'] == opt:
                                matching = True
                                select.select_by_visible_text(opt)

                        if matching == False:
                            select.select_by_index(len(select.options)-1)


                    else:
                        driver.find_element(By.NAME,self.subjects).send_keys(self.formdata['subjects'])
            except Exception as e:
                print(f"Error encountered: {e}")
                # ここに追加のエラー処理を書くことができます。

            try:
                if self.body != '':
                    driver.find_element(By.NAME,self.body).send_keys(self.formdata['body'])
            except Exception as e:
                print(f"Error encountered: {e}")
                # ここに追加のエラー処理を書くことができます。


            def click_button(driver, button_texts):
                """
                トライするテキスト(button_texts)ごとに、
                1) //button[contains(text(), 'xxx')]
                2) //input[contains(@value, 'xxx')]
                の二種類のXPathを試し、見つかったらクリック。
                見つからなければFalseを返す。
                
                ログをたくさん仕込んでデバッグしやすくした。
                """
                print(f"[click_button] Trying button_texts = {button_texts}")

                for text in button_texts:
                    print(f"[click_button] Checking text: {text}")
                    xpaths = [
                        f"//button[contains(text(), '{text}')]",
                        f"//input[contains(@value, '{text}')]"
                    ]

                    for xpath in xpaths:
                        print(f"  [click_button] Trying XPath: {xpath}")
                        try:
                            # 要素が「DOM上に存在」するだけでなく、「クリック可能」になるまで待機
                            button = WebDriverWait(driver, 10).until(
                                EC.element_to_be_clickable((By.XPATH, xpath))
                            )
                            print(f"    [click_button] Found element. Attempting to click. (tag_name={button.tag_name}, text={button.text}")
                            print(f"    Value Attribute: {button.get_attribute('value')}")
                            print(f"    Outer HTML:\n{button.get_attribute('outerHTML')}")
                            print(f"    [click_button] Found element. Attempting to click. {button}")

                            print(f"    [click_button] Found element. Checking properties...")

                            # 1️⃣ 表示されているか確認
                            if not button.is_displayed():
                                print("    [click_button] Button is NOT visible. Forcing display...")
                                driver.execute_script("arguments[0].style.display = 'block';", button)
                                time.sleep(1)

                            # 2️⃣ `disabled` になっていないかチェック
                            if button.get_attribute("disabled"):
                                print("    [click_button] Button is DISABLED. Enabling it...")
                                driver.execute_script("arguments[0].removeAttribute('disabled');", button)
                                time.sleep(1)

                            # 3️⃣ `scrollIntoView()` を試す
                            print("    [click_button] Scrolling into view...")
                            driver.execute_script("arguments[0].scrollIntoView();", button)
                            time.sleep(1)

                            # 4️⃣ 通常の `click()` を試す
                            print("    [click_button] Attempting normal click...")
                            try:
                                button.click()
                                print(f"    [click_button] Click succeeded on XPath: {xpath}")
                                return True
                            except Exception as e:
                                print(f"    [click_button] Normal click failed: {type(e).__name__}, {str(e)}")

                            # 5️⃣ JavaScript click() を試す
                            print("    [click_button] Trying JavaScript click()...")
                            driver.execute_script("arguments[0].click();", button)
                            print("    [click_button] JavaScript click succeeded!")
                            print(f"    [click_button] Click succeeded on XPath: {xpath}")
                            return True

                        except Exception as e:
                            # 例外が発生してもループを続け、別のXPathを試す
                            print(f"    [click_button] Exception while searching/clicking element for XPath: {xpath}")
                            # print(f"    [click_button] Exception: {type(e).__name__}, {str(e)}")
                            # print(traceback.format_exc())

                # すべてのパターンを試しても成功しなかった場合
                print("[click_button] No matching button found or no clickable state.")
                return False

            try:
                before = driver.title
                def handle_alert(driver):
                    """アラートが表示されたらOKを押す"""
                    try:
                        WebDriverWait(driver, 3).until(EC.alert_is_present())  # 3秒間アラートが出るのを待つ
                        alert = driver.switch_to.alert  # アラートを取得
                        print(f"[handle_alert] Alert detected: {alert.text}")  # アラートの内容を表示
                        alert.accept()  # OKを押す
                        print("[handle_alert] Alert accepted.")
                        return True
                    except NoAlertPresentException:
                        print("[handle_alert] No alert detected.")
                        return False
                    except UnexpectedAlertPresentException as e:
                        print(f"[handle_alert] Unexpected alert: {str(e)}")
                        return False                    
                    except Exception as e:
                        print(f"[handle_alert] Error in confirm_and_submit: {e}")
                        return False
                def confirm_and_submit(driver):
                    """
                    1. 「確認」ボタンを押す
                    2. 確認画面に遷移したら、もう一度「送信」ボタンを探して押す
                    """
                    try:
                        before_title = driver.title  # 現在のページタイトルを取得

                        # 「確認」ボタンをクリック
                        if click_button(driver, ['確認']):
                            print("Clicked the 'confirm' button")
                            time.sleep(2)  # ページ遷移を待つ

                            # ページタイトルが変わったか（確認画面に遷移したか）チェック
                            after_title = driver.title
                            if before_title != after_title:
                                print("[confirm_and_submit] Confirm page detected, proceeding to submission...")

                                # もう一度「送信」ボタンを探してクリック
                                if click_button(driver, ['送信']):
                                    print("Clicked the 'submit' button")
                                    return "OK"
                                else:
                                    print("Error: Could not find 'submit' button after confirm.")
                                    return "NG"
                            else:
                                print("[confirm_and_submit] No page transition detected, '送信' button might be on the same page.")

                                # そのまま「送信」ボタンがある可能性もあるので、試す
                                if click_button(driver, ['送信']):
                                    print("Clicked the 'submit' button")
                                    return "OK"
                                else:
                                    print("Error: Could not find 'submit' button even on the same page.")
                                    return "NG"

                        else:
                            print("Error: Could not find 'confirm' button.")
                            return "NG"

                    except Exception as e:
                        print(f"Error in confirm_and_submit: {e}")
                        return "NG"
                # "確認" または "送信" ボタンをクリック
                if click_button(driver, ['確認']):
                    print("Clicked the 'confirm' button")
                    handle_alert(driver)
                elif click_button(driver, ['送信']):
                    print("Clicked the 'submit' button")
                    handle_alert(driver)
                else:
                    print("Error: Could not find either 'confirm' or 'submit' button")
                    driver.close()
                    return 'NG'

                # 送信が成功したかどうかの確認（タイトルの変更を確認）
                time.sleep(3)  # 送信後のページへの移動を待機
                after = driver.title
                page_source = driver.page_source
                print("before",before)
                print("after",after)
                driver.close()
                return 'OK'
                if before != after or "ありがとう" in page_source or "完了" in page_source:  # タイトルが変わった場合、送信成功と判断
                    driver.close()
                    return 'OK'
                else:
                    driver.close()
                    print("Error: Failed to submit form")
                    return 'NG'

            except Exception as e:
                print(f"Error: {e}")
                print("submit false")
                driver.close()
                return 'NG'


            """
            ## 規約 プライバシーポリシーチェック
            try:
                print(self.kiyakucheck)
                if self.kiyakucheck != {}:
                    checking = driver.find_element(By.XPATH,"//input[@name='" + self.kiyakucheck['name']+"']")
                    if not checking.is_selected():
                        driver.execute_script("arguments[0].click();", checking)
            except Exception as e:
                print("同意エラー")
                print(e)

            ## 連絡方法
            try:
                if self.response_contact != []:
                    for radioarray in self.response_contact:
                        radian = driver.find_elements(By.XPATH, "//input[@type='radio' and @name='"+ radioarray['name']+"']")
                        for radio in radian:
                            r = radio.get_attribute(("value"))
                            if "どちらでも" in r:
                                radio.click()

            except Exception as e:
                print("押せない")
                print(e)

            try:
                print(self.industry)
                if self.industry != []:
                    for radioarray in self.industry:
                        radian = driver.find_elements(By.XPATH, "//input[@type='radio' and @name='"+ radioarray['name']+"']")
                        for radio in radian:
                            r = radio.get_attribute(("value"))
                            if 'メーカー' in r:
                                driver.execute_script("arguments[0].click();", radio)
            except Exception as e:
                print(traceback.format_exc())

            time.sleep(2)
            """

#switch = 1 #debug mode
switch = 0

if switch == 0:
    print("本番モード")
elif switch == 1:
    form_data = {
        "company":"Tamagawa",
        "company_kana":"たまがわ",
        "manager":"多摩川 フラン",
        "manager_kana":"タマガワ フラン",
        "phone":"090-3795-5760",
        "fax":"",
        "address":"東京都目黒区中目黒",
        "mail":"info@tamagawa.com",
        "subjects":"システム開発！Webデザインは、YSMT製作所へ！",
        "body":"はじめまして。 たまがわです。この度、Webデザインを始めてみました。"
    }
    url = "https://ri-plus.jp/contact"
    #url = "https://www.amo-pack.com/contact/index.html"

