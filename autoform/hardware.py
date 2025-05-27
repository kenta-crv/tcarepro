from selenium import webdriver
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.chrome import service as fs
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.support.select import Select
from selenium.webdriver.chrome.options import Options
from selenium.common.exceptions import NoAlertPresentException, UnexpectedAlertPresentException, TimeoutException, NoSuchElementException, ElementNotInteractableException
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
                    elif (name.startswith("メールアドレス") or "mail" in name.lower()):
                            is_confirm_by_name = "確認" in name
                            
                            if is_confirm_by_name:
                                # This field is identified as a CONFIRMATION email field by its label
                                if name.startswith("メールアドレス"): # Strong match for confirmation
                                    # If self.mail was mistakenly set to this field's name (e.g., by a weak name match earlier)
                                    # and this label clearly marks it as confirmation, clear self.mail.
                                    if self.mail == olist["name"]:
                                        self.mail = '' 
                                    self.mail_c = olist["name"] # Set/overwrite self.mail_c
                                elif not self.mail_c: # Weaker "mail" in label match for confirmation
                                    # Only set if self.mail_c hasn't been set by a stronger match (name or label)
                                    self.mail_c = olist["name"]
                            else:
                                # This field is identified as a PRIMARY email field candidate by its label
                                if label.startswith("メールアドレス"): # Strong match for primary email
                                    # If self.mail_c was mistakenly set to this field's name, clear it.
                                    if self.mail_c == olist["name"]:
                                        self.mail_c = ''
                                    self.mail = olist["name"] # Set/overwrite self.mail with this strong match
                                elif "mail" in label.lower(): # Weaker "mail" in label match for primary
                                    # Only set self.mail if it's not already set by a strong label match
                                    # or a previous name match.
                                    if not self.mail:
                                        self.mail = olist["name"]
                                    # If self.mail is already set (by name or strong label) and self.mail_c is not,
                                    # and this current field (olist["name"]) is different from self.mail,
                                    # this weakly matched primary field could be an unlabeled confirmation.
                                    elif not self.mail_c and self.mail != olist["name"]:
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
                    elif (label.startswith("メールアドレス") or "mail" in label.lower()):
                        is_confirm_by_label = "確認" in label
                        
                        if is_confirm_by_label:
                            # This field is identified as a CONFIRMATION email field by its label
                            if label.startswith("メールアドレス"): # Strong match for confirmation
                                # If self.mail was mistakenly set to this field's name (e.g., by a weak name match earlier)
                                # and this label clearly marks it as confirmation, clear self.mail.
                                if self.mail == olist["name"]:
                                    self.mail = '' 
                                self.mail_c = olist["name"] # Set/overwrite self.mail_c
                            elif not self.mail_c: # Weaker "mail" in label match for confirmation
                                # Only set if self.mail_c hasn't been set by a stronger match (name or label)
                                self.mail_c = olist["name"]
                        else:
                            # This field is identified as a PRIMARY email field candidate by its label
                            if label.startswith("メールアドレス"): # Strong match for primary email
                                # If self.mail_c was mistakenly set to this field's name, clear it.
                                if self.mail_c == olist["name"]:
                                    self.mail_c = ''
                                self.mail = olist["name"] # Set/overwrite self.mail with this strong match
                            elif "mail" in label.lower(): # Weaker "mail" in label match for primary
                                # Only set self.mail if it's not already set by a strong label match
                                # or a previous name match.
                                if not self.mail:
                                    self.mail = olist["name"]
                                # If self.mail is already set (by name or strong label) and self.mail_c is not,
                                # and this current field (olist["name"]) is different from self.mail,
                                # this weakly matched primary field could be an unlabeled confirmation.
                                elif not self.mail_c and self.mail != olist["name"]:
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
        options = Options() # Use Options from selenium.webdriver.chrome.options
        options.add_argument('--headless')
        options.add_argument('--no-sandbox')
        options.add_argument('--disable-dev-shm-usage')
        options.add_argument('--disable-gpu')
        options.add_argument("window-size=1280x800") # Adjusted window size
        options.add_argument("user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.212 Safari/537.36")

        # Consider making chromedriver path configurable or rely on webdriver_manager
        try:
            serv = Service(ChromeDriverManager().install())
        except Exception as e:
            print(f"Failed to install/initialize ChromeDriver: {e}")
            return {"status": "NG", "reason": "chromedriver_initialization_failed"}

        driver = None
        try:
            driver = webdriver.Chrome(service=serv, options=options)
            driver.get(self.endpoint)
            time.sleep(3) # Allow initial page load

            initial_url = driver.current_url
            initial_title = driver.title.lower()

            # --- Helper Functions within go_selenium ---
            def click_button_by_text(driver_instance, button_texts_list, exact_match=False):
                for text_val in button_texts_list:
                    try:
                        if exact_match:
                            xpath_query = f"//button[normalize-space()='{text_val}'] | //input[@type='submit' and normalize-space(@value)='{text_val}'] | //input[@type='button' and normalize-space(@value)='{text_val}'] | //a[normalize-space()='{text_val}' and (contains(concat(' ', normalize-space(@class), ' '), ' btn ') or contains(concat(' ', normalize-space(@class), ' '), ' button ')]"
                        else:
                            xpath_query = f"//button[contains(normalize-space(), '{text_val}')] | //input[@type='submit' and contains(normalize-space(@value), '{text_val}')] | //input[@type='button' and contains(normalize-space(@value), '{text_val}')] | //a[contains(normalize-space(), '{text_val}') and (contains(concat(' ', normalize-space(@class), ' '), ' btn ') or contains(concat(' ', normalize-space(@class), ' '), ' button ')]"
                        
                        buttons = driver_instance.find_elements(By.XPATH, xpath_query)
                        if buttons:
                            for button in buttons:
                                if button.is_displayed() and button.is_enabled():
                                    driver_instance.execute_script("arguments[0].scrollIntoView({block: 'center'});", button)
                                    time.sleep(0.5)
                                    button.click()
                                    print(f"Clicked button with text/value containing: '{text_val}'")
                                    return True
                    except (NoSuchElementException, ElementNotInteractableException) as e_click:
                        print(f"Could not click button '{text_val}': {e_click}")
                    except Exception as e_general:
                        print(f"Error finding/clicking button '{text_val}': {e_general}")
                print(f"No clickable button found for texts: {button_texts_list}")
                return False

            def check_success_messages(driver_instance, initial_url_val, initial_title_val):
                time.sleep(3) # Wait for potential redirects or dynamic content
                current_url = driver_instance.current_url
                current_title = driver_instance.title.lower()
                page_source = driver_instance.page_source.lower()

                # Check 1: Significant URL change (and not an error page)
                if initial_url_val != current_url and not any(err_kw in current_url.lower() for err_kw in ["error", "fail", "エラー", "失敗", "contact", "inquiry"]): # Avoid counting reload of contact page as success
                    if not any(kw in current_url.lower() for kw in ["confirm", "check", "preview"]): # Ensure it's not just a confirmation page
                        print(f"Success: URL changed from '{initial_url_val}' to '{current_url}'")
                        return True
                
                # Check 2: Title change (less reliable, but can be an indicator)
                # if initial_title_val != current_title and not any(err_kw in current_title for err_kw in ["error", "fail", "エラー", "失敗"]):
                #     print(f"Success: Title changed from '{initial_title_val}' to '{current_title}'")
                #     return True

                success_keywords = [
                    "ありがとうございます", "有難う", "完了しました", "送信しました", "受け付けました", "お問い合わせいただき",
                    "thank you", "complete", "submitted", "success", "received your message"
                ]
                for keyword in success_keywords:
                    if keyword in page_source:
                        # Further check: ensure the keyword is visible
                        try:
                            elements_with_keyword = driver_instance.find_elements(By.XPATH, f"//*[contains(translate(normalize-space(), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '{keyword}') and string-length(normalize-space(text())) > 0]")
                            if any(el.is_displayed() for el in elements_with_keyword):
                                print(f"Success: Found visible keyword '{keyword}' in page source.")
                                return True
                        except:
                            pass # Ignore if elements can't be checked
                return False

            def check_error_messages(driver_instance):
                page_source = driver_instance.page_source.lower()
                # More specific error keywords
                error_keywords = [
                    "エラーが発生しました", "必須項目です", "入力してください", "正しくありません", "入力に誤りがあります",
                    "is required", "please enter", "invalid format", "error occurred", "failed"
                ]
                # Check for visible error messages associated with inputs or general error areas
                common_error_xpaths = [
                    "//*[contains(@class, 'error') and string-length(normalize-space(text())) > 0]",
                    "//*[contains(@class, 'alert') and string-length(normalize-space(text())) > 0]",
                    "//p[contains(translate(normalize-space(text()), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), 'エラー')]",
                    "//span[contains(translate(normalize-space(text()), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '必須')]"
                ]
                for xpath in common_error_xpaths:
                    try:
                        error_elements = driver_instance.find_elements(By.XPATH, xpath)
                        if any(el.is_displayed() for el in error_elements):
                            for el in error_elements:
                                if el.is_displayed():
                                    print(f"Failure: Found visible error message by XPath '{xpath}': {el.text[:100]}")
                                    return True
                    except: pass
                
                for keyword in error_keywords:
                    if keyword in page_source:
                         try: # Check for visible error messages
                            error_elements = driver_instance.find_elements(By.XPATH, f"//*[(self::p or self::span or self::div or self::li) and (contains(translate(text(), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '{keyword}')) and string-length(normalize-space(text())) > 0]")
                            if any(el.is_displayed() for el in error_elements):
                                print(f"Failure: Found visible error message with keyword '{keyword}'.")
                                return True
                         except: pass
                # Check for input fields marked with error classes or aria-invalid
                error_inputs = driver_instance.find_elements(By.XPATH, "//input[@aria-invalid='true' or contains(@class, 'error') or contains(@class, 'invalid')] | //textarea[@aria-invalid='true' or contains(@class, 'error') or contains(@class, 'invalid')]")
                if any(el.is_displayed() for el in error_inputs):
                    print("Failure: Found input fields marked with error classes or aria-invalid.")
                    return True
                return False

            def check_for_captcha(driver_instance):
                captcha_indicators_xpath = [
                    "//iframe[contains(@src, 'recaptcha') or contains(@title, 'reCAPTCHA')]",
                    "//*[contains(@class, 'g-recaptcha') or contains(@id, 'recaptcha') or contains(@data-sitekey, '')]", # Check for data-sitekey
                    "//img[contains(@src, 'captcha') or contains(@id, 'captcha')]",
                    "//input[contains(@name, 'captcha') or contains(@id, 'captcha') or contains(@placeholder, '画像認証')]"
                ]
                page_source_lower = driver_instance.page_source.lower()
                captcha_keywords_text = ["captcha", "画像認証", "認証コード", "ロボットではない", "security check", "verify you are human"]

                for xpath_query in captcha_indicators_xpath:
                    try:
                        if driver_instance.find_elements(By.XPATH, xpath_query):
                            print(f"CAPTCHA detected by XPath: {xpath_query}")
                            return True
                    except: pass
                
                for keyword in captcha_keywords_text:
                    if keyword in page_source_lower:
                        print(f"CAPTCHA detected by keyword in page source: '{keyword}'")
                        return True
                return False

            # --- CAPTCHA Check Before Filling ---
            if check_for_captcha(driver):
                print("CAPTCHA detected on initial page load.")
                return {"status": "NG", "reason": "captcha_detected_on_load"}

            # --- Iframe Handling ---
            if self.iframe_mode:
                try:
                    iframes = driver.find_elements(By.TAG_NAME, 'iframe')
                    if iframes:
                        # Try to find a form-like iframe
                        found_form_iframe = False
                        for idx, iframe_el in enumerate(iframes):
                            try:
                                driver.switch_to.frame(iframe_el)
                                if driver.find_elements(By.XPATH, "//form"): # Check if form exists in this iframe
                                    print(f"Switched to iframe (index {idx}) containing a form.")
                                    found_form_iframe = True
                                    break 
                                else:
                                    driver.switch_to.parent_frame() # Switch back if no form
                            except Exception as e_iframe_switch:
                                print(f"Error switching to or checking iframe {idx}: {e_iframe_switch}")
                                driver.switch_to.default_content() # Ensure back to main if error
                        if not found_form_iframe and iframes: # Fallback to first iframe if specific one not found
                             driver.switch_to.default_content()
                             driver.switch_to.frame(iframes[0])
                             print("Switched to the first iframe as a fallback.")
                    else:
                        print("iframe_mode is true, but no iframe found.")
                        # return {"status": "NG", "reason": "iframe_not_found"} # Decide if this is critical
                except Exception as e:
                    print(f"Error switching to iframe: {e}")
                    return {"status": "NG", "reason": f"iframe_switch_error: {str(e)}"}
            
            # --- Field Filling ---
            # Map your formdata keys to the instance variables that hold field names
            field_data_map = {
                self.company: self.formdata.get('company'),
                self.company_kana: self.formdata.get('company_kana'),
                self.manager: self.formdata.get('manager'),
                self.manager_kana: self.formdata.get('manager_kana'),
                self.manager_first: self.formdata.get('manager_first'), # Assuming formdata has these if split
                self.manager_last: self.formdata.get('manager_last'),
                self.manager_first_kana: self.formdata.get('manager_first_kana'),
                self.manager_last_kana: self.formdata.get('manager_last_kana'),
                self.phone: self.formdata.get('phone'),
                self.fax: self.formdata.get('fax'),
                self.address: self.formdata.get('address'), # For a single address field
                self.zip: self.formdata.get('zip'), # For a single zip field
                self.mail: self.formdata.get('mail'),
                self.mail_c: self.formdata.get('mail'), # Email confirmation, use same email
                self.subjects: self.formdata.get('subjects'), # For subject line / inquiry type (if text)
                self.body: self.formdata.get('body'),
                self.url: self.formdata.get('url') # If there's a URL field
            }

            for field_html_name, value_to_fill in field_data_map.items():
                if field_html_name and value_to_fill:
                    try:
                        # Try input and textarea. Selects are handled separately.
                        elements = driver.find_elements(By.NAME, field_html_name)
                        if not elements: # Fallback to ID if name not found
                             elements = driver.find_elements(By.ID, field_html_name)
                        
                        for element in elements: # Iterate if multiple elements share a name (e.g. radio group)
                            if element.is_displayed() and element.is_enabled():
                                if element.tag_name == "input" and element.get_attribute("type") not in ["radio", "checkbox", "submit", "button", "hidden", "file"]:
                                    element.clear()
                                    element.send_keys(value_to_fill)
                                    print(f"Filled input '{field_html_name}' with '{value_to_fill[:30]}...'")
                                elif element.tag_name == "textarea":
                                    element.clear()
                                    element.send_keys(value_to_fill)
                                    print(f"Filled textarea '{field_html_name}' with '{value_to_fill[:30]}...'")
                                break # Assuming first interactable element is the target
                    except (NoSuchElementException, ElementNotInteractableException):
                        print(f"Field '{field_html_name}' not found or not interactable.")
                    except Exception as e_fill:
                        print(f"Error filling field '{field_html_name}': {e_fill}")
            
            # Specific handling for split phone numbers (if self.phone0,1,2 are set by logicer)
            if self.phone0 and self.phone1 and self.phone2 and self.formdata.get('phone'):
                try:
                    phone_parts = self.formdata['phone'].replace('‐', '-').replace('ー', '-').split('-')
                    if len(phone_parts) == 3:
                        driver.find_element(By.NAME, self.phone0).send_keys(phone_parts[0])
                        driver.find_element(By.NAME, self.phone1).send_keys(phone_parts[1])
                        driver.find_element(By.NAME, self.phone2).send_keys(phone_parts[2])
                        print("Filled split phone number.")
                except Exception as e_phone_split:
                    print(f"Error filling split phone number: {e_phone_split}")

            # Specific handling for select dropdowns (Prefecture, Subject if it's a select)
            # Prefecture
            if self.pref and self.formdata.get('address'): # self.pref is the name of the select tag
                try:
                    pref_element = driver.find_element(By.NAME, self.pref)
                    if pref_element.tag_name == "select" and pref_element.is_displayed() and pref_element.is_enabled():
                        select_obj = Select(pref_element)
                        address_lower = self.formdata['address'].lower()
                        # Iterate through options to find a match (partial or full)
                        found_pref = False
                        for option in select_obj.options:
                            option_text_lower = option.text.lower()
                            if option_text_lower and option_text_lower in address_lower: # Simple substring match
                                select_obj.select_by_visible_text(option.text)
                                print(f"Selected prefecture '{option.text}'")
                                found_pref = True
                                break
                        if not found_pref: print(f"Could not auto-select prefecture for '{self.pref}'")
                except Exception as e_pref:
                    print(f"Error selecting prefecture '{self.pref}': {e_pref}")
            
            # Subject if it's a select (self.subjects might be input or select)
            if self.subjects and self.formdata.get('subjects'):
                try:
                    subject_element = driver.find_element(By.NAME, self.subjects)
                    if subject_element.tag_name == "select" and subject_element.is_displayed() and subject_element.is_enabled():
                        select_obj = Select(subject_element)
                        subject_value = self.formdata['subjects']
                        found_subject_option = False
                        for option in select_obj.options: # Try exact match first
                            if option.text == subject_value or option.get_attribute('value') == subject_value:
                                select_obj.select_by_visible_text(option.text) # or select_by_value
                                print(f"Selected subject option: '{option.text}'")
                                found_subject_option = True
                                break
                        if not found_subject_option and len(select_obj.options) > 1: # Fallback: select a common default or last
                             # Avoid selecting the "Please select" option if value is empty or placeholder
                            for opt_idx in range(len(select_obj.options) -1, 0, -1): # Iterate backwards, skip first if it's placeholder
                                if select_obj.options[opt_idx].get_attribute('value') != "":
                                    select_obj.select_by_index(opt_idx)
                                    print(f"Selected fallback subject option: '{select_obj.options[opt_idx].text}'")
                                    break
                except (NoSuchElementException, ElementNotInteractableException):
                     pass # If it's not a select, it would have been handled by the general input filler
                except Exception as e_subj_select:
                    print(f"Error selecting subject from dropdown '{self.subjects}': {e_subj_select}")


            # Handle Radio Buttons (self.radio is a list of {"radioname": name, "value": value_to_select_if_known})
            for radio_group_info in self.radio: # self.radio should contain {'radioname': 'name_of_group'}
                radio_name = radio_group_info.get('radioname')
                # value_to_select = radio_group_info.get('value') # Your logicer seems to store all values, not a specific one to pick
                if radio_name:
                    try:
                        radio_buttons = driver.find_elements(By.NAME, radio_name)
                        if radio_buttons:
                            # Default: select the first available radio button if no specific value is targeted
                            # Or, if your formdata has a key that matches radio_name, use that value
                            selected_a_radio = False
                            for radio_btn in radio_buttons:
                                if radio_btn.is_displayed() and radio_btn.is_enabled():
                                    # Add logic here if you want to select a specific value based on self.formdata
                                    # For now, clicking the first one that's interactable.
                                    radio_btn.click()
                                    print(f"Clicked radio button from group '{radio_name}' (value: {radio_btn.get_attribute('value')})")
                                    selected_a_radio = True
                                    break 
                            if not selected_a_radio:
                                print(f"No interactable radio button found for group '{radio_name}'")
                    except Exception as e_radio:
                        print(f"Error with radio button group '{radio_name}': {e_radio}")
            
            # Handle Checkboxes (self.chk is a list of {"checkname": name, "value": value_if_specific})
            # This includes the agreement/kiyaku checkbox
            checkboxes_to_tick = []
            if self.kiyakucheck and self.kiyakucheck.get('name'):
                 checkboxes_to_tick.append(self.kiyakucheck.get('name'))
            
            for chk_info in self.chk: # self.chk from logicer
                chk_name = chk_info.get('checkname')
                if chk_name and chk_name not in checkboxes_to_tick: # Avoid double-adding kiyaku
                    # Add logic here if you need to decide whether to check it based on 'value' or formdata
                    # For now, assume all identified checkboxes (other than kiyaku) should be checked if found
                    checkboxes_to_tick.append(chk_name)

            for chk_name_to_tick in list(set(checkboxes_to_tick)): # Use set to ensure unique names
                try:
                    checkboxes = driver.find_elements(By.NAME, chk_name_to_tick)
                    if not checkboxes: checkboxes = driver.find_elements(By.ID, chk_name_to_tick) # Fallback to ID

                    for checkbox in checkboxes:
                        if checkbox.is_displayed() and checkbox.is_enabled() and not checkbox.is_selected():
                            # driver.execute_script("arguments[0].scrollIntoView(true);", checkbox)
                            # time.sleep(0.2)
                            checkbox.click() # JavaScript click can be more reliable: driver.execute_script("arguments[0].click();", checkbox)
                            print(f"Clicked checkbox: '{chk_name_to_tick}'")
                            break # Assume one checkbox per name is sufficient
                except Exception as e_chk:
                    print(f"Error with checkbox '{chk_name_to_tick}': {e_chk}")

            time.sleep(1) # Brief pause after filling form

            # --- CAPTCHA Check Before Submission ---
            if check_for_captcha(driver):
                print("CAPTCHA detected before attempting submission.")
                return {"status": "NG", "reason": "captcha_detected_before_submit"}

            # --- Submission Process ---
            # Common texts for confirm buttons (Japanese and English)
            confirm_button_texts = ['確認画面へ', '確認する', '内容確認', '次へ', '進む', '入力内容の確認', 'Confirm', 'Next', 'Continue', 'Preview']
            # Common texts for final submit buttons
            submit_button_texts = ['送信する', '登録する', '申し込む', 'この内容で送信', '上記内容で送信', 'Submit', 'Send', 'Register', 'Complete', '送信']

            clicked_confirm = click_button_by_text(driver, confirm_button_texts)
            
            if clicked_confirm:
                print("On confirmation page (assumed after clicking confirm-like button).")
                time.sleep(2) # Wait for confirmation page to load
                if check_error_messages(driver):
                    return {"status": "NG", "reason": "error_on_confirmation_page"}
                if check_for_captcha(driver): # Check for CAPTCHA on confirmation page
                    return {"status": "NG", "reason": "captcha_on_confirmation_page"}
                
                clicked_final_submit = click_button_by_text(driver, submit_button_texts)
                if not clicked_final_submit:
                    # If no explicit submit, sometimes the confirm button itself is the final step
                    # or the page auto-submits. We rely on check_success_messages.
                    print("No distinct final submit button found/clicked after confirm. Will check for success messages.")
                    # return {"status": "NG", "reason": "final_submit_button_not_found_after_confirm"}
            else:
                # No confirm button found, try direct submission
                print("No confirm button found, attempting direct submission.")
                clicked_direct_submit = click_button_by_text(driver, submit_button_texts)
                if not clicked_direct_submit:
                    return {"status": "NG", "reason": "submit_button_not_found_on_form"}

            # --- Final Success/Failure Check ---
            if check_success_messages(driver, initial_url, initial_title):
                return {"status": "OK", "reason": "submission_successful_message_detected"}
            elif check_error_messages(driver): # Check for errors again after final submit attempt
                return {"status": "NG", "reason": "error_message_after_final_submission_attempt"}
            else:
                # Fallback: if URL changed significantly and no explicit errors, consider it a potential success
                current_url_final = driver.current_url
                if initial_url != current_url_final and not any(err_kw in current_url_final.lower() for err_kw in ["error", "fail", "contact", "inquiry"]):
                     if not any(kw in current_url_final.lower() for kw in ["confirm", "check", "preview"]): # Ensure it's not stuck on a confirm page
                        print(f"URL changed from '{initial_url}' to '{current_url_final}' with no explicit errors. Assuming success.")
                        return {"status": "OK", "reason": "url_changed_no_errors_detected"}

                return {"status": "NG", "reason": "submission_outcome_unclear_no_success_or_error_message"}

        except TimeoutException:
            print("TimeoutException occurred during Selenium operation.")
            traceback.print_exc()
            return {"status": "NG", "reason": "selenium_timeout"}
        except Exception as e:
            print(f"General error in go_selenium: {e}")
            traceback.print_exc()
            # Try to get current URL if driver is available
            current_url_on_error = "unknown"
            if driver:
                try:
                    current_url_on_error = driver.current_url
                except: pass
            return {"status": "NG", "reason": f"exception_in_go_selenium: {str(e)[:100]} at {current_url_on_error}"}
        finally:
            if driver:
                driver.quit()
                
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
        "address":"東京都目黒区中目黒", # Consider adding a prefecture for self.pref testing
        "mail":"info@tamagawa.com",
        "subjects":"システム開発のご相談", # Test subject
        "body":"はじめまして。 たまがわと申します。\nこの度、貴社のウェブサイトを拝見し、システム開発についてご相談させて頂きたくご連絡いたしました。\nよろしくお願いいたします。" # Test body
    }
    # url = "https://ri-plus.jp/contact"
    # url = "https://www.amo-pack.com/contact/index.html"

    print(f"--- Debug Mode Activated for URL: {url} ---")
    try:
        # Instantiate Place_enter with the debug data
        # This assumes your Place_enter.__init__ is ready to parse the form
        # and logicer correctly identifies fields.
        automation_instance = Place_enter(url, form_data)

        # Check if form parsing was successful (optional, depends on your __init__)
        if not automation_instance.form:
            print("DEBUG: Place_enter failed to find or initialize the form. Exiting debug run.")
        else:
            print(f"DEBUG: Place_enter initialized. Identified field names (examples):")
            print(f"  Company field name: {automation_instance.company}")
            print(f"  Manager field name: {automation_instance.manager}")
            print(f"  Email field name: {automation_instance.mail}")
            print(f"  Email Confirm field name: {automation_instance.mail_c}")
            print(f"  Body field name: {automation_instance.body}")
            print(f"  Kiyaku checkbox name: {automation_instance.kiyakucheck.get('name') if automation_instance.kiyakucheck else 'Not identified'}")
            # print(f"  Namelist from logicer: {automation_instance.namelist}") # Can be very verbose

            # Call the go_selenium method
            print("DEBUG: Calling go_selenium...")
            result = automation_instance.go_selenium()

            # Print the result
            print(f"--- Debug Mode Selenium Result ---")
            print(f"Status: {result.get('status')}")
            print(f"Reason: {result.get('reason')}")

    except Exception as e_debug:
        print(f"--- Debug Mode Error ---")
        print(f"An error occurred during the debug run: {e_debug}")
        traceback.print_exc()

    print(f"--- Debug Mode Finished ---")