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
import requests
from bs4 import BeautifulSoup
import time
import sys
import traceback

options = webdriver.ChromeOptions()
options.add_argument('--headless')
#options.binary_location = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
start = time.perf_counter()
#serv = Service(ChromeDriverManager().install())
serv = Service(executable_path='/usr/local/bin/chromedriver')

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
                    data_list.extend(extract_select_data(child))
                    continue

                if dt_text:
                    data['label'] = dt_text
                data_list.append(data)
            
            return data_list
        
        def find_and_add_to_namelist(self, tables):
            data_list = []
            
            for row in tables.find_all('tr'):
                for col in row.find_all('td'):
                    dt_text = col.find_previous_sibling('dt').get_text(strip=True) if col.find_previous_sibling('dt') else None  # <dt>のテキストを取得
                    for elem_type in ['input', 'textarea', 'select']:
                        elem = col.find(elem_type)
                        if elem and 'name' in elem.attrs:
                            name = elem['name']
                            data = {
                                'object': elem_type,
                                'name': name,
                                'label': dt_text  
                            }
                            if elem_type == 'input':
                                data['type'] = elem.get('type')
                                data['value'] = elem.get('value')
                            data_list.append(data)

            return data_list


        namelist = []

        if self.target_table() == 0 and self.target_dtdl() == 0:#formだが、dtdlなし
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
            namelist = []
            if not tables.find_all('tbody'):
                print("tbody is not.")

            # Search for keywords in <td> and add to namelist
            for table in self.target_table():
                find_and_add_to_namelist(table)

        self.namelist = namelist 
        self.logicer(self.namelist)
        print(self.body)
        

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
            return self.form.find('table')
        else: 
            return 0

    def target_dtdl(self):
        if self.form.find('dl'):
            print('dtdlを見つけました')
            return self.form.find_all('dl')
        else: 
            return 0
    
    

    def logicer(self, lists):
        for list in lists:
            label = list.get('label', '')
                      
            if label:
                if list["object"] == "input":
                    if "会社" in label:
                        self.company = list["name"]
                    elif "会社ふりがな" in label or "会社フリガナ" in label:
                        self.company_kana = list["name"]
                    elif "名前" in label:
                        self.manager = list["name"]
                    elif "ふりがな" in label or "フリガナ" in label:
                        self.manager_kana = list["name"]
                    elif "郵便番号" in label:
                        self.zip = list["name"]
                    elif "住所" in label:
                        self.address = list["name"]
                    elif "都道府県" in label:
                        self.pref = list["name"]
                    elif "市区町村" in label:
                        self.address_city = list["name"]
                    elif "番地" in label:
                        self.address_thin = list["name"]
                    elif "電話番号" in label:
                        self.phone = list["name"]
                    elif "メールアドレス" in label or "email" in label:
                        self.mail = list["name"]
                    elif "用件" in label or "お問い合わせ" in label or "本文" in label:
                        self.subjects = list["name"]
                    elif list["type"] == "radio":
                        self.radio.append({"radioname": list["name"], "value": list["value"]})
                    elif list["type"] == "checkbox":
                        self.chk.append({"checkname": list["name"], "value": list["value"]})
                elif list["object"] == "textarea":
                    if "用件" in label or "お問い合わせ" in label or "本文" in label:
                        self.body = list["name"]
                elif list["object"] == "select":
                    if "都道府県" in label:
                        self.pref = list["name"]
                    if "用件" in label or "お問い合わせ" in label or "本文" in label:
                        self.subjects = list["name"]
                
    def go_selenium(self):
        driver = webdriver.Chrome(service=serv,options=options)
        driver.get(self.endpoint)
        time.sleep(3)
        
        def input_text_field(driver, field_name, value):
            """テキストフィールドに値を入力するための関数"""
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


        if self.iframe_mode == True:
            try:
                iframe = driver.find_element(By.TAG_NAME,'iframe')
            except Exception as e:
                print("iframe not found")
                print(e)
            driver.switch_to.frame(iframe)

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
                select_radio_button(driver, radio_info['name'])

            for checkbox_info in self.chk:
                select_checkbox(driver, checkbox_info['name'])


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
                
        
            if self.zip != '':
                r = requests.get("https://api.excelapi.org/post/zipcode?address=" + self.formdata['address'])
                postman = r.text
                try:
                    driver.find_element(By.NAME,self.zip).send_keys(postman[:3]+ "-" + postman[3:])
                except Exception as e:
                    print("Error: Failed to submit form")
                    print(e)

            if self.pref != '':
                pref_data = ''
                pref = [
                    "北海道","青森県","岩手県","宮城県","秋田県","山形県","福島県",
                    "茨城県","栃木県","群馬県","埼玉県","千葉県","東京都","神奈川県",
                    "新潟県","富山県","石川県","福井県","山梨県","長野県","岐阜県",
                    "静岡県","愛知県","三重県","滋賀県","京都府","大阪府","兵庫県",
                    "奈良県","和歌山県","鳥取県","島根県","岡山県","広島県","山口県",
                    "徳島県","香川県","愛媛県","高知県","福岡県","佐賀県","長崎県",
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

            try:
                if self.subjects != '':
                    matching = False
                    if self.subjects_radio_badge == True:
                        print(self.chk)
                        for c in self.chk:
                            if 'お問い合わせ' in c['value']:
                                checking = driver.find_element(By.XPATH,"//input[@name='" + c['name']+"' and @value='" + c['value']+"']")
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
            
            
            try:
                before = driver.title                

                try:
                    # 送信内容を確認するボタンが表示されるまで待機
                    confirm_button = WebDriverWait(driver, 10).until(
                        EC.presence_of_element_located((By.XPATH, "//button[contains(text(), '送信内容を確認する')]"))
                    )
                    confirm_button.click()

                    # 上記内容で送信するボタンが表示されるまで待機
                    submit_button = WebDriverWait(driver, 10).until(
                        EC.presence_of_element_located((By.XPATH, "//input[@value='上記内容で送信する']"))
                    )
                    submit_button.click()
                except Exception as e:
                    print(f"Error: {e}")

                # 4. 送信が成功したかどうかの確認（ここでは例としてタイトルの変更を確認）
                time.sleep(3)  # 送信後のページへの移動を待機
                after = driver.title
                if before != after:  # タイトルが変わった場合、送信成功と判断
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
                select_radio_button(driver, radio_info['name'])

            for checkbox_info in self.chk:
                select_checkbox(driver, checkbox_info['name'])

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
                        "北海道","青森県","岩手県","宮城県","秋田県","山形県","福島県",
                        "茨城県","栃木県","群馬県","埼玉県","千葉県","東京都","神奈川県",
                        "新潟県","富山県","石川県","福井県","山梨県","長野県","岐阜県",
                        "静岡県","愛知県","三重県","滋賀県","京都府","大阪府","兵庫県",
                        "奈良県","和歌山県","鳥取県","島根県","岡山県","広島県","山口県",
                        "徳島県","香川県","愛媛県","高知県","福岡県","佐賀県","長崎県",
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


            try:
                before = driver.title                

                try:
                    # 送信内容を確認するボタンが表示されるまで待機
                    confirm_button = WebDriverWait(driver, 10).until(
                        EC.presence_of_element_located((By.XPATH, "//button[contains(text(), '送信内容を確認する')]"))
                    )
                    confirm_button.click()

                    # 上記内容で送信するボタンが表示されるまで待機
                    submit_button = WebDriverWait(driver, 10).until(
                        EC.presence_of_element_located((By.XPATH, "//input[@value='上記内容で送信する']"))
                    )
                    submit_button.click()
                except Exception as e:
                    print(f"Error: {e}")

                # 4. 送信が成功したかどうかの確認（ここでは例としてタイトルの変更を確認）
                time.sleep(3)  # 送信後のページへの移動を待機
                after = driver.title
                if before != after:  # タイトルが変わった場合、送信成功と判断
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

switch = 1 #debug mode

if switch == 0:
    print("本番モード")
elif switch == 1:
    form_data = {
        "company":"Tamagawa",
        "company_kana":"たまがわ",
        "manager":"多摩川　フラン",
        "manager_kana":"タマガワ　フラン",
        "phone":"090-3795-5760",
        "fax":"",
        "address":"東京都目黒区中目黒",
        "mail":"info@tamagawa.com",
        "subjects":"システム開発！Webデザインは、YSMT製作所へ！",
        "body":"はじめまして。 たまがわです。この度、Webデザインを始めてみました。"
    }
    #url = "https://ri-plus.jp/contact"
    url = "https://www.amo-pack.com/contact/index.html" 
    p = Place_enter(url,form_data)  
    print(p.go_selenium())