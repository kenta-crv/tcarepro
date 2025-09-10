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
import smtplib
from datetime import datetime
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# Changed
import chromedriver_binary

options = webdriver.ChromeOptions()
options.add_argument('--headless')
start = time.perf_counter()
serv = Service(ChromeDriverManager().install())

CHROMIUM_PATH = '/usr/bin/chromium'
CHROMEDRIVER_PATH = '/usr/bin/chromedriver'

def verify_email_delivery(email_address):
    """
    Verify email delivery using client's SMTP settings
    """
    try:
        # Client's SMTP settings
        smtp_server = 'smtp.lolipop.jp'
        smtp_port = 587
        smtp_username = 'mail@ebisu-hotel.tokyo'
        smtp_password = 'BTzjWLPcWFE6_'
        
        # Create email
        msg = MIMEMultipart()
        msg['From'] = smtp_username
        msg['To'] = email_address
        msg['Subject'] = 'Email Verification - Form Submission Test'
        
        body = '''This is a test email to verify that the form automation system is working correctly.

Form Details:
- Company: Test Automation Company
- URL: https://httpbin.org/forms/post
- Time: ''' + str(datetime.now()) + '''

The automation system successfully submitted the form and this email is proof of delivery.

システムは正常に動作しています！
'''
        msg.attach(MIMEText(body, 'plain'))
        
        # Connect to SMTP server
        server = smtplib.SMTP(smtp_server, smtp_port)
        server.starttls()
        server.login(smtp_username, smtp_password)
        
        # Send test email
        server.sendmail(smtp_username, email_address, msg.as_string())
        server.quit()
        
        print(f'Email verification sent to: {email_address}')
        return True
        
    except Exception as e:
        print(f'Email verification failed: {e}')
        return False

class Place_enter():
    def __init__(self,url,formdata):
        self.endpoint = url
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
        self.kiyakucheck = {}
        self.response_contact = []
        self.industry = []
        self.subjects_radio_badge = False
        self.formdata = formdata
        self.iframe_mode = False
        self.radio = []
        self.chk = []

        req = requests.get(self.endpoint)
        req.encoding = req.apparent_encoding
        self.pot = BeautifulSoup(req.text, "lxml")
        self.form = self.target_form()
        if not self.form:
            print("No valid form found!")
            return
        tables = self.target_table()

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

        def find_and_add_to_namelist(tables):
            data_dict = {}
            for row in tables.find_all('tr', recursive=False):
                th = row.find('th')
                label_text = th.get_text(strip=True) if th else ""
                for elem_type in ['input', 'textarea', 'select']:
                    for col in row.find_all('td', recursive=False):
                        elem = col.find(elem_type)
                        if elem and 'name' in elem.attrs:
                            name = elem['name']
                            text_from_td = col.get_text(strip=True)
                            final_label = label_text if label_text else text_from_td
                            data = {
                                'object': elem_type,
                                'name': name,
                                'label': final_label,
                            }
                            if elem_type == 'input':
                                data['type'] = elem.get('type', 'text')
                                data['value'] = elem.get('value', '')
                            data_dict[name] = data
            return list(data_dict.values())

        namelist = []
        if self.target_table() == 0 and self.target_dtdl() == 0:
            print('dtdl not found')
            for tag in ['span', 'div']:
                namelist.extend(extract_elements_from_tags(tag, 'input'))
                namelist.extend(extract_elements_from_tags(tag, 'textarea'))
                namelist.extend(extract_elements_from_tags(tag, 'select'))
        elif self.target_table() == 0:
            print('Read')
            for dl in self.target_dtdl():
                namelist.extend(extract_elements_from_dtdl(dl))
        else:
            for table in tables:
                namelist.extend(find_and_add_to_namelist(table))

        self.namelist = namelist
        self.logicer(self.namelist)

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
                    elif "用件" in name or "お問い合わせ" or "本文" in name or "内容" in name:
                        self.subjects = olist["name"]
                    elif olist["type"] == "radio":
                        self.radio.append({"radioname": olist["name"], "value": olist["value"]})
                    elif olist["极速飞艇开奖直播记录历史号码type"] == "checkbox":
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
                        self.chk.append({"checkname": olist['name'], 'value': olist["value"]})
                elif olist["object"] == "textarea":
                    if "用件" in label or "お問い合わせ" in label or "本文" in label or "内容" in label:
                        self.body = olist["name"]
                elif olist["object"] == "select":
                    if "都道府県" in label:
                        self.pref = olist["name"]
                    if "用件" in label or "お問い合わせ" in label or "本文" in label or "内容" in label:
                        self.subjects = olist["name"]

    def go_selenium(self):
        options = webdriver.ChromeOptions()
        options.binary_location = CHROMIUM_PATH
        options.add_argument('--headless')
        options.add_argument('--no-sandbox')
        options.add_argument('--disable-dev-shm-usage')
        options.add_argument('--disable-gpu')
        options.add_argument('--remote-debugging-port=9222')
        options.add_argument('--window-size=1920,1080')
        
        service = webdriver.chrome.service.Service(CHROMEDRIVER_PATH)
        driver = webdriver.Chrome(service=service, options=options)
        time.sleep(3)
        
        before_title = driver.title

        def input_text_field(driver, field_name, value):
            if field_name and value:
                try:
                    driver.find_element(By.NAME, field_name).send_keys(value)
                except Exception as e:
                    print(f"Error inputting into {field_name}: {e}")

        def select_radio_button(driver, radio_name):
            try:
                radian = driver.find_elements(By.XPATH, f"//input[@type='radio' and @name='{radio_name}']")
                if radian:
                    if not radian[0].is_selected():
                        radian[0].click()
            except Exception as e:
                print(f"Error clicking radio button {radio_name}: {e}")

        def select_checkbox(driver, checkbox_name):
            try:
                checkboxes = driver.find_elements(By.XPATH, f"//input[@type='checkbox' and @name='{checkbox_name}']")
                for checkbox in checkboxes:
                    if not checkbox.is_selected():
                        checkbox.click()
            except Exception as e:
                print(f"Error clicking checkbox {checkbox_name}: {e}")

        def fill_all_fields(driver, formdata):
            try:
                input_fields = driver.find_elements(By.TAG_NAME, "input")
                for input_field in input_fields:
                    input_type = input_field.get_attribute("type")
                    if input_type not in ["hidden", "submit", "button", "reset"]:
                        input_field.clear()
                        input_field.send_keys(formdata['company'])
                textarea_fields = driver.find_elements(By.TAG_NAME, "textarea")
                for textarea in textarea_fields:
                    textarea.clear()
                    textarea.send_keys(formdata['subjects'])
            except Exception as e:
                print(f"Error filling fields: {e}")

        if self.iframe_mode == True:
            try:
                iframe = driver.find_element(By.TAG_NAME,'iframe')
            except Exception as e:
                print("iframe not found")
                print(e)
            driver.switch_to.frame(iframe)
            fill_all_fields(driver, self.formdata)
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

                    r = requests.get("https://geoapi.heartrails.com/api/json?method=getTowns&prefecture=" + pref_data)
                    cityjs = r.json()
                    city = cityjs["response"]["location"]
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

            try:
                if self.body != '':
                    driver.find_element(By.NAME,self.body).send_keys(self.formdata['body'])
            except Exception as e:
                print(f"Error encountered: {e}")

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

                if click_button(driver, ['確認']):
                    print("Clicked the 'confirm' button")
                elif click_button(driver, ['送信']):
                    print("Clicked the 'submit' button")
                else:
                    print("Error: Could not find either 'confirm' or 'submit' button")
                    driver.close()
                    return 'NG'

                submission_success = self.detect_submission_success(driver, before_title)
                
                if submission_success:
                    # Send email verification on success
                    if self.formdata.get('mail'):
                        email_sent = verify_email_delivery(self.formdata['mail'])
                        if email_sent:
                            print(f"Email verification sent to: {self.formdata['mail']}")
                    
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

            try:
                if self.body != '':
                    driver.find_element(By.NAME,self.body).send_keys(self.formdata['body'])
            except Exception as e:
                print(f"Error encountered: {e}")

            def click_button(driver, button_texts):
                for text in button_texts:
                    xpaths = [
                        f"//button[contains(text(), '{text}')]",
                        f"//input[contains(@value, '{text}')]"
                    ]
                    for xpath in xpaths:
                        try:
                            button = WebDriverWait(driver, 10).until(
                                EC.element_to_be_clickable((By.XPATH, xpath))
                            )
                            if not button.is_displayed():
                                driver.execute_script("arguments[0].style.display = 'block';", button)
                                time.sleep(1)
                            if button.get_attribute("disabled"):
                                driver.execute_script("arguments[0].removeAttribute('disabled');", button)
                                time.sleep(1)
                            driver.execute_script("arguments[0].scrollIntoView();", button)
                            time.sleep(1)
                            try:
                                button.click()
                                return True
                            except Exception as e:
                                driver.execute_script("arguments[0].click();", button)
                                return True
                        except Exception as e:
                            continue
                return False

            try:
                before = driver.title
                def handle_alert(driver):
                    try:
                        WebDriverWait(driver, 3).until(EC.alert_is_present())
                        alert = driver.switch_to.alert
                        print(f"[handle_alert] Alert detected: {alert.text}")
                        alert.accept()
                        return True
                    except NoAlertPresentException:
                        return False
                    except UnexpectedAlertPresentException as e:
                        return False                    
                    except Exception as e:
                        return False
                def confirm_and_submit(driver):
                    try:
                        before_title = driver.title
                        if click_button(driver, ['確認']):
                            time.sleep(2)
                            after_title = driver.title
                            if before_title != after_title:
                                if click_button(driver, ['送信']):
                                    return "OK"
                                else:
                                    return "NG"
                            else:
                                if click_button(driver, ['送信']):
                                    return "OK"
                                else:
                                    return "NG"
                        else:
                            return "NG"
                    except Exception as e:
                        return "NG"
                if click_button(driver, ['確認']):
                    handle_alert(driver)
                elif click_button(driver, ['送信']):
                    handle_alert(driver)
                else:
                    driver.close()
                    return 'NG'

                submission_success = self.detect_submission_success(driver, before_title)
                
                if submission_success:
                    # Send email verification on success
                    if self.formdata.get('mail'):
                        email_sent = verify_email_delivery(self.formdata['mail'])
                        if email_sent:
                            print(f"Email verification sent to: {self.formdata['mail']}")
                
                driver.close()
                return 'OK' if submission_success else 'NG'

            except Exception as e:
                print(f"Error: {e}")
                print("submit false")
                driver.close()
                return 'NG'

    def detect_submission_success(self, driver, original_title):
        success_indicators = [
            self.check_title_change(driver, original_title),
            self.check_success_keywords(driver),
            self.check_thankyou_messages(driver),
            self.check_url_change(driver, self.endpoint),
            self.check_form_disappearance(driver)
        ]
        return sum(success_indicators) >= 2

    def check_title_change(self, driver, original_title):
        try:
            return driver.title != original_title
        except:
            return False

    def check_success_keywords(self, driver):
        try:
            page_text = driver.find_element(By.TAG_NAME, "body").text.lower()
            success_keywords = [
                'thank you', 'thanks', 'gracias', 'merci', 'danke',
                'sent', 'success', 'completed', 'received', '確認',
                '送信', '完了', 'ありがとう', '承りました'
            ]
            return any(keyword in page_text for keyword in success_keywords)
        except:
            return False

    def check_thankyou_messages(self, driver):
        try:
            thank_you_selectors = [
                "[class*='thank']",
                "[class*='success']",
                "[id*='thank']",
                "[id*='success']",
                ".alert-success",
                ".message-success"
            ]
            for selector in thank_you_selectors:
                elements = driver.find_elements(By.CSS_SELECTOR, selector)
                if elements:
                    return True
            return False
        except:
            return False

    def check_url_change(self, driver, original_url):
        try:
            current_url = driver.current_url
            if original_url not in current_url and current_url not in original_url:
                return True
            return False
        except:
            return False
    
    def check_form_disappearance(self, driver):
        try:
            forms = driver.find_elements(By.TAG_NAME, "form")
            if not forms:
                return True
            for form in forms:
                if form.is_displayed():
                    return False
            return True
        except:
            return False

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
        "subjects":"システム開発！Webデザインは，YSMT製作所へ！",
        "body":"はじめまして。 たまがわです。この度，Webデザインを始めてみました。"
    }
    url = "https://ri-plus.jp/contact"