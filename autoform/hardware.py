import logging
import json
from selenium import webdriver
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager # For managing ChromeDriver
from selenium.webdriver.support.select import Select
from selenium.webdriver.chrome.options import Options
from selenium.common.exceptions import (
    NoAlertPresentException, UnexpectedAlertPresentException, TimeoutException,
    NoSuchElementException, ElementNotInteractableException, SessionNotCreatedException,
    WebDriverException, ElementClickInterceptedException
)
import requests
from bs4 import BeautifulSoup
import time
import sys
import traceback

class Place_enter():
    def __init__(self,url,formdata):
        self.endpoint = url
        self.formdata = formdata

        # Initialize fields (these will be populated by logicer with HTML field names)
        self.company = ''
        self.company_kana = ''
        self.manager = ''
        self.manager_kana = ''
        self.manager_first = ''
        self.manager_last = ''
        self.manager_first_kana = ''
        self.manager_last_kana = ''
        self.pref = '' # For a dedicated prefecture select/input field
        self.phone = ''
        self.phone0 = '' # For split phone numbers
        self.phone1 = ''
        self.phone2 = ''
        self.fax = ''
        self.address = '' # For a full address field
        self.address_pref = '' # For a dedicated prefecture field if separate from full address
        self.address_city = '' # For a dedicated city field
        self.address_thin = '' # For address line after city/pref
        self.zip = ''
        self.mail = ''
        self.mail_c = '' # Email confirmation field
        self.url_field_name = '' # Field name for website URL input
        self.subjects = ''
        self.body = ''
        self.namelist = [] # List of all parseable form elements
        self.hidden_fields = [] # Store hidden fields separately
        self.kiyakucheck = {} # For agreement checkbox
        self.iframe_mode = False # Flag if form is likely in an iframe
        self.radio = [] # For radio button groups
        self.chk = [] # For general checkboxes (non-agreement)

        # Initial HTML fetch and parsing
        try:
            # Use a common user-agent for requests
            headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.212 Safari/537.36'}
            req = requests.get(self.endpoint, headers=headers, timeout=15) # Increased timeout
            req.encoding = req.apparent_encoding # Detect encoding
            self.pot = BeautifulSoup(req.text, "lxml") # Use lxml parser
            self.form = self.target_form() # Attempt to identify the main form
        except requests.RequestException as e:
            print(f"Error fetching URL {self.endpoint} with requests: {e}")
            self.pot = None
            self.form = None
            return # Cannot proceed if initial fetch fails

        # If no form found, check for iframes (this part uses a temporary Selenium instance)
        if not self.form:
            print("No valid form found initially with requests.")
            if self.pot and self.pot.find('iframe'): # Basic check if any iframe tag exists
                print("Iframe tag detected. Attempting to parse iframe content using Selenium in __init__...")
                temp_driver = None
                try:
                    temp_options = webdriver.ChromeOptions()
                    temp_options.add_argument('--headless')
                    temp_options.add_argument('--disable-gpu') # Often necessary for headless
                    temp_options.add_argument('--no-sandbox') # Can help in some environments
                    temp_options.add_argument('--disable-dev-shm-usage') # Overcomes limited resource problems
                    temp_options.add_argument("user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36") # Consistent UA
                    temp_options.add_argument('log-level=3')
                    temp_options.add_experimental_option('excludeSwitches', ['enable-logging'])

                    temp_serv = Service(ChromeDriverManager().install())
                    temp_driver = webdriver.Chrome(service=temp_serv, options=temp_options)
                    temp_driver.get(self.endpoint)
                    WebDriverWait(temp_driver, 10).until(EC.presence_of_element_located((By.TAG_NAME, 'iframe')))
                    
                    iframes_on_page = temp_driver.find_elements(By.TAG_NAME, 'iframe')
                    found_form_in_iframe_init = False
                    for iframe_el_init in iframes_on_page:
                        try:
                            temp_driver.switch_to.frame(iframe_el_init)
                            if temp_driver.find_elements(By.XPATH, "//form"): # Check if form tag exists in this iframe
                                source = BeautifulSoup(temp_driver.page_source, "lxml").prettify()
                                self.pot = BeautifulSoup(source, "lxml") # Update self.pot with iframe content
                                self.form = self.target_form() # Try to find form again
                                self.iframe_mode = True # Set iframe mode
                                if self.form:
                                    print("Form found within an iframe during __init__.")
                                    found_form_in_iframe_init = True
                                    break 
                                else: # Form tag not found in this iframe, switch back
                                    temp_driver.switch_to.parent_frame()
                            else: # No form tag in this iframe
                                temp_driver.switch_to.parent_frame()
                        except Exception as e_iframe_switch_init:
                            print(f"Error switching or checking iframe in __init__: {e_iframe_switch_init}")
                            temp_driver.switch_to.default_content() # Ensure back to main content
                    if not found_form_in_iframe_init:
                         print("No form found even within iframes during __init__.")

                except Exception as e_iframe_init_main:
                    print(f"Error during iframe processing in __init__ (webdriver part): {e_iframe_init_main}")
                finally:
                    if temp_driver:
                        temp_driver.quit()
            else:
                print('No form and no iframe detected by initial requests in __init__.')
                return

        if not self.form:
            print("Still no form found after all checks in __init__. Cannot proceed with field parsing.")
            return

        # --- Field Extraction Helper Functions (internal to __init__) ---
        def extract_input_data(element):
            data = {}
            input_type = element.get('type')
            name = element.get('name')
            if not name: return None 

            if input_type in ['radio', 'checkbox']:
                data = {'object': 'input', 'name': name, 'type': input_type, 'value': element.get('value')}
            elif input_type == 'hidden':
                data = {'object': 'hidden', 'name': name, 'value': element.get('value')}
            else: # text, email, tel, password, etc.
                data = {'object': 'input', 'name': name, 'type': input_type if input_type else 'text', 'value': element.get('value')}
            
            if element.get('placeholder'): data['placeholder'] = element.get('placeholder')
            if element.get('id'): data['id'] = element.get('id')
            return data

        def extract_textarea_data(element):
            name = element.get('name')
            if not name: return None
            data = {'object': 'textarea', 'name': name}
            if element.get('class'): data['class'] = element.get('class')
            if element.get('id'): data['id'] = element.get('id')
            return data

        def extract_select_data(element):
            name = element.get('name')
            if not name: return [] # Return empty list if no name
            
            select_data = {'object': 'select', 'name': name}
            if element.get('class'): select_data['class'] = element.get('class')
            if element.get('id'): select_data['id'] = element.get('id')
            
            options_data = []
            for option_tag in element.find_all('option'):
                opt_val = option_tag.get('value')
                opt_text = option_tag.get_text(strip=True)
                if opt_val is not None or opt_text: # Add if value or text exists
                    options_data.append({'value': opt_val, 'text': opt_text})
            select_data['options'] = options_data
            return [select_data] # Return list containing the select element dict

        # --- Main Field Parsing Logic (within __init__) ---
        namelist_temp = []
        # Find all relevant elements directly within the identified form
        for child_element in self.form.find_all(['input', 'textarea', 'select'], recursive=True):
            item_data = None
            if child_element.name == 'input': item_data = extract_input_data(child_element)
            elif child_element.name == 'textarea': item_data = extract_textarea_data(child_element)
            elif child_element.name == 'select':
                select_items_list = extract_select_data(child_element)
                if select_items_list: item_data = select_items_list[0]

            if item_data and item_data.get('name'): # Must have a name
                # Attempt to find an associated label
                label_text = ""
                element_id = child_element.get('id')
                if element_id: # Try <label for="element_id">
                    label_tag = self.form.find('label', {'for': element_id})
                    if label_tag: label_text = label_tag.get_text(strip=True)
                
                if not label_text: # Fallback: parent <label> or preceding text
                    parent_label_tag = child_element.find_parent('label')
                    if parent_label_tag:
                        child_text_content = ' '.join(child_element.stripped_strings)
                        parent_label_text_content = ' '.join(parent_label_tag.stripped_strings)
                        # Remove child's text from parent's text if nested
                        label_text = parent_label_text_content.replace(child_text_content, '').strip()
                    else: # Check common parent containers for label-like text
                        container = child_element.find_parent(['td', 'dd', 'p', 'div', 'li'])
                        if container:
                            label_like_element = container.find(['th', 'dt', 'strong', 'b'], recursive=False) # Direct child
                            if label_like_element: label_text = label_like_element.get_text(strip=True)
                                
                item_data['label'] = label_text
                
                # Avoid adding duplicates by name (first one encountered wins)
                if not any(existing_item.get('name') == item_data.get('name') for existing_item in namelist_temp):
                    namelist_temp.append(item_data)
        
        self.namelist = [item for item in namelist_temp if item.get('object') != 'hidden']
        self.hidden_fields = [item for item in namelist_temp if item.get('object') == 'hidden']

        if not self.namelist:
            print("Warning: Namelist is empty after parsing. Field identification might fail.")
        else:
            self.logicer(self.namelist) # Call logicer to map fields
        # print(f"Logicer input namelist ({len(self.namelist)} items): {self.namelist[:3]}")
        # print(f"Hidden fields ({len(self.hidden_fields)} items): {self.hidden_fields[:3]}")


    def target_form(self): # Identifies the most likely contact form on the page
        if not self.pot: return None
        forms = self.pot.find_all('form')
        if not forms: return None

        potential_forms = []
        for form_element in forms:
            # Get attributes for scoring
            class_attr = " ".join(form_element.get('class', [])).lower()
            id_attr = form_element.get('id', '').lower()
            action_attr = form_element.get('action', '').lower()
            name_attr = form_element.get('name', '').lower()

            # Keywords to skip common non-contact forms
            skip_keywords = ['search', 'login', 'cart', 'subscribe', 'filter', 'sort', 'ナビゲーション', '検索', 'newsletter', 'コメント', 'comment']
            if any(kw in attr for attr in [class_attr, id_attr, action_attr, name_attr] for kw in skip_keywords):
                if 'contact' not in action_attr and 'inquiry' not in action_attr : # unless action is explicitly contact/inquiry
                    continue

            score = 0
            # Score based on number of relevant input types
            score += len(form_element.find_all('input', {'type': ['text', 'email', 'tel']})) * 2
            score += len(form_element.find_all('textarea')) * 3
            score += len(form_element.find_all('select')) * 1

            # Boost score for contact-related keywords in attributes
            contact_keywords = ['contact', 'inquiry', 'mail', 'send', 'submit', 'form', '問い合わせ', 'お問い合わせ', 'ご意見', '資料請求', '見積']
            if any(kw in action_attr for kw in contact_keywords): score += 15
            if any(kw in id_attr for kw in contact_keywords): score += 7
            if any(kw in name_attr for kw in contact_keywords): score += 7
            if any(kw in class_attr for kw in contact_keywords): score += 5
            
            # Boost for presence of common contact field names/placeholders within the form's text
            form_text_lower = form_element.get_text().lower()
            if any(indicator in form_text_lower for indicator in ['お名前', 'メールアドレス', '電話番号', 'お問い合わせ内容', 'your-name', 'e-mail']):
                score += 5

            # Penalize forms with very few fields unless action is highly relevant
            if score < 6 and not any(kw in action_attr for kw in contact_keywords[:4]): # contact, inquiry, mail, send
                score = 0 

            if score > 0:
                potential_forms.append({'form_element': form_element, 'score': score})
        
        if not potential_forms: return None
        
        best_form = max(potential_forms, key=lambda x: x['score'])
        # print(f"Selected form with score {best_form['score']}: ID='{best_form['form_element'].get('id', '')}', Action='{best_form['form_element'].get('action', '')}'")
        return best_form['form_element']


    def logicer(self, lists): # Maps form field names to standard data points
        # Keywords for different fields (Japanese and English)
        kw_company = ["会社", "社名", "店名", "貴社", "法人名", "屋号", "company", "organization", "business name"]
        kw_company_kana = ["会社ふりがな", "会社フリガナ", "社名ふりがな", "社名フリガナ", "company kana", "company furigana"]
        
        kw_manager_last_name = ["姓", "名字", "last name", "family name"]
        kw_manager_first_name = ["名", "名前（名）", "first name", "given name"]
        kw_manager_full_name = ["名前", "氏名", "担当者", "ご担当者", "name", "full name", "contact person"] 

        kw_manager_last_kana = ["姓ふりがな", "姓フリガナ", "last name kana"]
        kw_manager_first_kana = ["名ふりがな", "名フリガナ", "first name kana"]
        kw_manager_full_kana = ["ふりがな", "フリガナ", "氏名ふりがな", "氏名フリガナ", "kana name", "furigana name"]

        kw_zip = ["郵便番号", "zip", "postal code", "〒"]
        kw_pref = ["都道府県", "prefecture"]
        kw_address_city = ["市区町村", "市町村", "city", "郡"]
        kw_address_thin = ["番地", "それ以降の住所", "町名", "street address", "address line 1", "丁目", "建物名"]
        kw_address_full = ["住所", "所在地", "address"]

        kw_phone = ["電話番号", "連絡先電話番号", "phone", "tel", "でんわ"]
        kw_phone_split_ids = [["tel1", "phone1", "電話番号1"], ["tel2", "phone2", "電話番号2"], ["tel3", "phone3", "電話番号3"]]

        kw_fax = ["fax", "ファックス"]
        kw_mail = ["メールアドレス", "mail", "email", "e-mail", "メアド"]
        kw_mail_confirm = ["メールアドレス確認", "mail confirm", "email confirmation", "確認用メールアドレス"]
        
        kw_url = ["url", "ホームページ", "website", "サイト", "貴社url"]
        kw_subjects = ["件名", "題名", "subject", "title", "お問い合わせ種類", "inquiry type", "ご用件", "用件"]
        kw_body = ["内容", "本文", "詳細", "message", "details", "inquiry body", "お問い合わせ内容", "ご質問"]

        kw_agreement = ["同意", "規約", "プライバシーポリシー", "個人情報", "agreement", "terms", "policy", "承諾"]

        def check_keywords_match(text_sources, keywords, exclusion_keywords=None):
            # text_sources is a list of strings (e.g., [name_attr, label_text, placeholder_text])
            # keywords is a list of keywords to look for
            # exclusion_keywords is a list of keywords that, if present, negate the match
            texts_lower = [str(s).lower() for s in text_sources if s]
            for text_l in texts_lower:
                if any(kw.lower() in text_l for kw in keywords):
                    if exclusion_keywords:
                        if not any(ex_kw.lower() in text_l for ex_kw in exclusion_keywords):
                            return True # Keyword found, and no exclusion keyword found
                    else:
                        return True # Keyword found, no exclusions to check
            return False

        assigned_field_names = set() # Keep track of HTML field names already assigned

        # Iterate multiple times for precedence (e.g., specific name parts before full name)
        # Pass 1: More specific fields (name parts, email confirm, split phone)
        for item in lists:
            name_attr = item.get('name')
            if not name_attr or name_attr in assigned_field_names: continue
            
            sources_to_check = [name_attr, item.get('label', ''), item.get('placeholder', '')]

            if not self.manager_last and check_keywords_match(sources_to_check, kw_manager_last_name):
                self.manager_last = name_attr; assigned_field_names.add(name_attr)
            elif not self.manager_first and check_keywords_match(sources_to_check, kw_manager_first_name):
                self.manager_first = name_attr; assigned_field_names.add(name_attr)
            elif not self.manager_last_kana and check_keywords_match(sources_to_check, kw_manager_last_kana, kw_company):
                self.manager_last_kana = name_attr; assigned_field_names.add(name_attr)
            elif not self.manager_first_kana and check_keywords_match(sources_to_check, kw_manager_first_kana, kw_company):
                self.manager_first_kana = name_attr; assigned_field_names.add(name_attr)
            elif not self.mail_c and check_keywords_match(sources_to_check, kw_mail_confirm):
                self.mail_c = name_attr; assigned_field_names.add(name_attr)
            elif not self.phone0 and check_keywords_match(sources_to_check, kw_phone_split_ids[0]):
                self.phone0 = name_attr; assigned_field_names.add(name_attr)
            elif not self.phone1 and check_keywords_match(sources_to_check, kw_phone_split_ids[1]):
                self.phone1 = name_attr; assigned_field_names.add(name_attr)
            elif not self.phone2 and check_keywords_match(sources_to_check, kw_phone_split_ids[2]):
                self.phone2 = name_attr; assigned_field_names.add(name_attr)

        # Pass 2: General fields
        for item in lists:
            name_attr = item.get('name')
            obj_type = item.get('object') # 'input', 'textarea', 'select'
            input_type_attr = item.get('type') # e.g., 'text', 'email', 'radio'

            if not name_attr or name_attr in assigned_field_names: continue
            sources_to_check = [name_attr, item.get('label', ''), item.get('placeholder', '')]

            if not self.company and check_keywords_match(sources_to_check, kw_company):
                self.company = name_attr; assigned_field_names.add(name_attr)
            elif not self.company_kana and check_keywords_match(sources_to_check, kw_company_kana):
                self.company_kana = name_attr; assigned_field_names.add(name_attr)
            elif not self.manager and check_keywords_match(sources_to_check, kw_manager_full_name, kw_company):
                self.manager = name_attr; assigned_field_names.add(name_attr)
            elif not self.manager_kana and check_keywords_match(sources_to_check, kw_manager_full_kana, kw_company):
                self.manager_kana = name_attr; assigned_field_names.add(name_attr)
            elif not self.zip and check_keywords_match(sources_to_check, kw_zip):
                self.zip = name_attr; assigned_field_names.add(name_attr)
            elif not self.pref and obj_type == 'select' and check_keywords_match(sources_to_check, kw_pref): # Pref often a select
                self.pref = name_attr; assigned_field_names.add(name_attr)
            elif not self.address_city and check_keywords_match(sources_to_check, kw_address_city):
                self.address_city = name_attr; assigned_field_names.add(name_attr)
            elif not self.address_thin and check_keywords_match(sources_to_check, kw_address_thin, kw_address_city + kw_pref):
                self.address_thin = name_attr; assigned_field_names.add(name_attr)
            elif not self.address and check_keywords_match(sources_to_check, kw_address_full): # Full address if parts not found
                self.address = name_attr; assigned_field_names.add(name_attr)
            elif not self.phone and check_keywords_match(sources_to_check, kw_phone):
                self.phone = name_attr; assigned_field_names.add(name_attr)
            elif not self.fax and check_keywords_match(sources_to_check, kw_fax):
                self.fax = name_attr; assigned_field_names.add(name_attr)
            elif not self.mail and check_keywords_match(sources_to_check, kw_mail, kw_mail_confirm):
                self.mail = name_attr; assigned_field_names.add(name_attr)
            elif not self.url_field_name and check_keywords_match(sources_to_check, kw_url):
                self.url_field_name = name_attr; assigned_field_names.add(name_attr)
            elif not self.subjects and obj_type != 'textarea' and check_keywords_match(sources_to_check, kw_subjects, kw_body):
                self.subjects = name_attr; assigned_field_names.add(name_attr)
            elif not self.body and obj_type == 'textarea' and check_keywords_match(sources_to_check, kw_body): # Prefer textarea for body
                self.body = name_attr; assigned_field_names.add(name_attr)
            
            # Agreement Checkbox (can be separate from other assignments)
            if obj_type == 'input' and input_type_attr == 'checkbox':
                if not self.kiyakucheck.get("name") and check_keywords_match(sources_to_check, kw_agreement):
                    self.kiyakucheck = {"name": name_attr, "value": item.get("value")}
                    # Don't add to assigned_field_names here, as it's a special category
            
            # Store radio groups (first value encountered for the group)
            if obj_type == 'input' and input_type_attr == 'radio':
                if not any(r.get('radioname') == name_attr for r in self.radio):
                    self.radio.append({"radioname": name_attr, "value": item.get("value")}) # Store first value as example
            
            # Store other general checkboxes (if not agreement)
            if obj_type == 'input' and input_type_attr == 'checkbox' and self.kiyakucheck.get("name") != name_attr:
                 if not any(c.get('checkname') == name_attr for c in self.chk):
                     self.chk.append({"checkname": name_attr, "value": item.get("value")})

        # Post-logicer adjustments
        if self.mail and not self.mail_c: # If primary mail found, but no specific confirm field, try to find another mail field
            for item in lists:
                name_attr = item.get('name')
                if name_attr and name_attr != self.mail and name_attr not in assigned_field_names:
                    if check_keywords_match([name_attr, item.get('label','')], kw_mail):
                        self.mail_c = name_attr; assigned_field_names.add(name_attr); break
        
        if not self.body and self.subjects and check_keywords_match([self.subjects, ""], kw_body): # If subject seems like it's actually the body
            self.body = self.subjects
            self.subjects = "" # Clear subjects if it was misidentified
        
        # print(f"Logicer identified fields: mail='{self.mail}', mail_c='{self.mail_c}', company='{self.company}', manager='{self.manager}', phone='{self.phone}', body='{self.body}', subjects='{self.subjects}', kiyaku='{self.kiyakucheck.get('name')}'")


    def go_selenium(self):
        print(f"Starting Selenium process for URL: {self.endpoint}")
        if not self.form and not self.iframe_mode: # Check if __init__ successfully found a form
            print("Selenium cannot proceed: No form identified by __init__.")
            return {"status": "NG", "reason": "no_form_identified_for_selenium"}

        options = Options()
        options.add_argument('--headless')
        options.add_argument('--no-sandbox') # Essential for running as root or in Docker/CI
        options.add_argument('--disable-dev-shm-usage') # Overcomes limited resource problems in /dev/shm
        options.add_argument('--disable-gpu') # Often necessary for headless, avoids GPU-related issues
        options.add_argument("--window-size=1920,1080") # Set a common window size
        options.add_argument("user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36") # Use a standard UA
        options.add_argument("--disable-extensions")
        options.add_argument("--proxy-server='direct://'") # Ensure direct connection
        options.add_argument("--proxy-bypass-list=*")
        options.add_argument("--ignore-certificate-errors") # If dealing with self-signed certs (use cautiously)
        options.add_argument('log-level=3') # Suppress most console logs from Chrome/ChromeDriver
        options.add_experimental_option('excludeSwitches', ['enable-logging']) # Further suppress logs

        driver = None
        try:
            print("Initializing ChromeDriver via WebDriverManager...")
            # WebDriverManager will download and cache the correct ChromeDriver
            serv = Service(ChromeDriverManager().install())
            driver = webdriver.Chrome(service=serv, options=options)
            driver.set_page_load_timeout(15) # Increased page load timeout
            print("WebDriver initialized successfully.")

            driver.get(self.endpoint)
            print(f"Navigated to {self.endpoint}")
            time.sleep(1) # Small pause for initial JS rendering, consider WebDriverWait for specific elements if needed

            initial_url = driver.current_url
            initial_title = driver.title.lower() if driver.title else ""

            # --- Helper Functions within go_selenium ---
            def click_button_by_text(driver_instance, button_texts_list, exact_match=False, wait_time=7):
                # Tries to click buttons, submit inputs, or styled links
                xpath_templates = [
                    ".//button[{condition}]",
                    ".//input[@type='submit' and {condition_val}]",
                    ".//input[@type='button' and {condition_val}]",
                    ".//a[{condition} and (contains(concat(' ', normalize-space(@class), ' '), ' btn ') or contains(concat(' ', normalize-space(@class), ' '), ' button ') or @role='button')]"
                ]
                for text_val in button_texts_list:
                    for template in xpath_templates:
                        # Build XPath condition based on exact_match
                        condition_text = f"normalize-space()='{text_val}'" if exact_match else f"contains(normalize-space(), '{text_val}')"
                        condition_value = f"normalize-space(@value)='{text_val}'" if exact_match else f"contains(normalize-space(@value), '{text_val}')"
                        
                        current_xpath = template.format(condition=condition_text, condition_val=condition_value)
                        try:
                            # Wait for the element to be clickable
                            WebDriverWait(driver_instance, wait_time).until(
                                EC.element_to_be_clickable((By.XPATH, current_xpath))
                            )
                            buttons_found = driver_instance.find_elements(By.XPATH, current_xpath)
                            if buttons_found:
                                for button_el in buttons_found: # Iterate if multiple matches, click first interactable
                                    if button_el.is_displayed() and button_el.is_enabled():
                                        driver_instance.execute_script("arguments[0].scrollIntoView({block: 'center', inline: 'nearest'});", button_el)
                                        time.sleep(0.3) # Short pause after scroll
                                        button_el.click()
                                        print(f"Clicked button/element via XPath '{current_xpath}' for text: '{text_val}'")
                                        return True
                        except TimeoutException:
                            pass # Element not found or not clickable in time, try next
                        except ElementClickInterceptedException:
                            print(f"Button '{text_val}' click intercepted. Trying JS click.")
                            try:
                                driver_instance.execute_script("arguments[0].click();", button_el) # JS click as fallback
                                print(f"Clicked button via JS for text: '{text_val}'")
                                return True
                            except Exception as e_js_click_err:
                                print(f"JS click also failed for '{text_val}': {e_js_click_err}")
                        except Exception as e_click_gen:
                            print(f"Error finding/clicking button '{text_val}' with XPath '{current_xpath}': {type(e_click_gen).__name__}")
                print(f"No clickable button found for texts: {button_texts_list}")
                return False

            def check_success_messages(driver_instance, initial_url_val, initial_title_val):
                time.sleep(2.5) # Wait for page to potentially change/update
                current_url = driver_instance.current_url
                current_title = driver_instance.title.lower() if driver_instance.title else ""
                
                # Check 1: Significant URL change to a non-error, non-form, non-confirm page
                if initial_url_val.split('?')[0] != current_url.split('?')[0]: # Compare base URLs
                    # Keywords indicating still on form/error/confirm page
                    stay_keywords = ["error", "fail", "エラー", "失敗", "contact", "inquiry", "form", "regist", "confirm", "check", "preview", "入力"]
                    if not any(kw in current_url.lower() for kw in stay_keywords):
                        print(f"Success: URL changed significantly from '{initial_url_val}' to '{current_url}' (non-error/form/confirm page).")
                        return True

                # Check 2: Presence of success keywords in visible text on the page
                success_keywords = [
                    "ありがとうございます", "有難うございました", "完了しました", "送信しました", "受け付けました", "お問い合わせいただき",
                    "thank you", "complete", "submitted", "success", "received your message", "送信完了", "送信が完了しました", "承りました"
                ]
                for keyword in success_keywords:
                    try:
                        # Search for elements containing the keyword, ensuring they are visible
                        elements_with_keyword = driver_instance.find_elements(By.XPATH, f"//*[contains(translate(normalize-space(.), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '{keyword.lower()}') and string-length(normalize-space(text())) > 0]")
                        if any(el.is_displayed() for el in elements_with_keyword): # Check if any are visible
                            print(f"Success: Found visible keyword '{keyword}'.")
                            return True
                    except: pass # Ignore errors if element not found
                return False

            def check_error_messages(driver_instance):
                time.sleep(0.5) # Brief pause for error messages to render
                error_keywords = [ # Common error message texts
                    "エラーが発生しました", "必須項目です", "入力してください", "正しくありません", "入力に誤りがあります",
                    "is required", "please enter", "invalid format", "error occurred", "failed", "入力エラー", "ご確認ください",
                    "入力内容に誤りがあります", "必須", "入力されていません"
                ]
                # XPaths for common error message containers or classes
                common_error_xpaths = [
                    "//*[contains(@class, 'error') and string-length(normalize-space(text())) > 0 and not(self::script) and not(contains(@style,'display:none') or contains(@style,'visibility:hidden'))]",
                    "//*[contains(@class, 'alert') and (contains(@class,'error') or contains(@class,'danger')) and string-length(normalize-space(text())) > 0 and not(self::script) and not(contains(@style,'display:none') or contains(@style,'visibility:hidden'))]",
                    "//p[contains(translate(normalize-space(text()), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), 'エラー') and not(contains(@style,'display:none') or contains(@style,'visibility:hidden'))]",
                    "//span[contains(translate(normalize-space(text()), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '必須') and not(contains(@style,'display:none') or contains(@style,'visibility:hidden'))]"
                ]
                for xpath_query in common_error_xpaths:
                    try:
                        error_elements = driver_instance.find_elements(By.XPATH, xpath_query)
                        if any(el.is_displayed() for el in error_elements):
                            for el_err_msg in error_elements:
                                if el_err_msg.is_displayed(): print(f"Failure: Found visible error message by XPath '{xpath_query}': {el_err_msg.text[:100]}"); return True
                    except: pass
                
                for keyword in error_keywords: # Check for keywords in various text-containing elements
                    try:
                        error_elements = driver_instance.find_elements(By.XPATH, f"//*[(self::p or self::span or self::div or self::li or self::font or self::dt or self::dd) and (contains(translate(normalize-space(text()), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '{keyword.lower()}')) and string-length(normalize-space(text())) > 0 and not(contains(@style,'display:none') or contains(@style,'visibility:hidden'))]")
                        if any(el.is_displayed() for el in error_elements):
                            print(f"Failure: Found visible error message with keyword '{keyword}'."); return True
                    except: pass
                
                # Check for input fields marked with error classes or aria-invalid (common in modern forms)
                error_input_fields_xpath = "//input[@aria-invalid='true' or contains(@class, 'error') or contains(@class, 'invalid') or contains(@class, 'wpcf7-not-valid')] | //textarea[@aria-invalid='true' or contains(@class, 'error') or contains(@class, 'invalid') or contains(@class, 'wpcf7-not-valid')]"
                error_inputs = driver_instance.find_elements(By.XPATH, error_input_fields_xpath)
                if any(el.is_displayed() for el in error_inputs):
                    print("Failure: Found input fields marked with error classes or aria-invalid."); return True
                return False

            def check_for_captcha(driver_instance): # Detects various CAPTCHA types
                print("Checking for CAPTCHA...")
                # XPaths for common CAPTCHA elements (reCAPTCHA, hCaptcha, Turnstile, image captchas, input fields)
                captcha_element_xpaths = [
                    "//iframe[contains(@src, 'recaptcha') or contains(@title, 'reCAPTCHA') or contains(@title, 'captcha') or contains(@name, 'a-')]", # Google reCAPTCHA iframes
                    "//*[contains(@class, 'g-recaptcha') or contains(@id, 'recaptcha') or contains(@class, 'h-captcha') or contains(@id, 'h-captcha') or @data-sitekey or @data-captcha]", # reCAPTCHA/hCaptcha divs
                    "//div[@class='cf-turnstile']", # Cloudflare Turnstile
                    "//img[contains(@src, 'captcha') or contains(@id, 'captcha_image') or contains(@alt, 'captcha') or contains(@class, 'captcha')]", # Image-based CAPTCHAs
                    "//input[contains(@name, 'captcha') or contains(@id, 'captcha') or contains(@placeholder, '画像認証') or contains(@placeholder, '認証コード') or contains(@aria-label, 'captcha') or contains(@autocomplete, 'one-time-code')]" # CAPTCHA input fields
                ]
                # Keywords often found in text near CAPTCHAs
                captcha_text_keywords = ["captcha", "画像認証", "認証コード", "ロボットではない", "security check", "verify you are human", "recaptcha", "hcaptcha", "私はロボットではありません", "turnstile", "確認コード", "人間であることを証明", "表示されている文字を入力"]

                for xpath_query in captcha_element_xpaths: # Check for visible CAPTCHA elements
                    try:
                        elements = driver_instance.find_elements(By.XPATH, xpath_query)
                        if any(el.is_displayed() for el in elements): # Check if any are visible
                            print(f"CAPTCHA detected by visible element via XPath: {xpath_query}"); return True
                    except: pass # Ignore if element not found
                
                page_source_text_lower = driver_instance.page_source.lower() # Check full page source for keywords as a fallback
                for keyword in captcha_text_keywords:
                    if keyword.lower() in page_source_text_lower:
                        # More specific check if keyword is part of a visible text node on the page
                        try:
                            keyword_elements = driver_instance.find_elements(By.XPATH, f"//*[contains(translate(normalize-space(.), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '{keyword.lower()}') and string-length(normalize-space(text())) > 0]")
                            if any(el.is_displayed() for el in keyword_elements):
                                print(f"CAPTCHA detected by visible keyword in page: '{keyword}'"); return True
                        except: pass
                print("No obvious CAPTCHA detected.")
                return False

            # --- CAPTCHA Check Before Filling Form ---
            if check_for_captcha(driver):
                print("CAPTCHA detected on initial page load.")
                return {"status": "NG", "reason": "captcha_detected_on_load_unsolvable"}

            # --- Iframe Handling for Selenium (if self.iframe_mode was set in __init__) ---
            if self.iframe_mode:
                try:
                    WebDriverWait(driver, 10).until(EC.presence_of_element_located((By.TAG_NAME, 'iframe')))
                    iframes = driver.find_elements(By.TAG_NAME, 'iframe')
                    switched_to_correct_iframe = False
                    if iframes:
                        for idx, iframe_element in enumerate(iframes):
                            try:
                                driver.switch_to.frame(iframe_element)
                                # Check if a key form element (e.g., email field) is present in this iframe
                                if self.mail and driver.find_elements(By.NAME, self.mail): 
                                    print(f"Switched to iframe (index {idx}) containing expected form elements.")
                                    switched_to_correct_iframe = True
                                    break # Found the correct iframe
                                else: # Not the right iframe, switch back to parent
                                    driver.switch_to.parent_frame() 
                            except Exception as e_iframe_switch_loop:
                                print(f"Error switching/checking iframe {idx} in Selenium: {e_iframe_switch_loop}")
                                driver.switch_to.default_content() # Ensure we are back to main document
                        if not switched_to_correct_iframe and iframes: # Fallback: if no specific iframe matched, try the first one
                            print("Could not confirm form in a specific iframe, trying the first iframe as fallback.")
                            driver.switch_to.default_content()
                            driver.switch_to.frame(iframes[0])
                    else: # iframe_mode was true, but Selenium found no iframes
                        print("iframe_mode is true, but no iframe found by Selenium on page. Proceeding in main document.")
                        self.iframe_mode = False # Reset flag if no iframe actually handled
                except Exception as e_iframe_handling_main:
                    print(f"Error handling iframe in Selenium: {e_iframe_handling_main}")
                    return {"status": "NG", "reason": f"selenium_iframe_error: {str(e_iframe_handling_main)}"}
            
            # --- Field Filling Logic ---
            # Map identified field names (self.company, self.mail etc.) to data from self.formdata
            field_to_data_map = {
                self.company: self.formdata.get('company'),
                self.company_kana: self.formdata.get('company_kana'),
                self.manager: self.formdata.get('manager'), # Full name
                self.manager_kana: self.formdata.get('manager_kana'), # Full kana
                self.manager_last: self.formdata.get('manager_last'),
                self.manager_first: self.formdata.get('manager_first'),
                self.manager_last_kana: self.formdata.get('manager_last_kana'),
                self.manager_first_kana: self.formdata.get('manager_first_kana'),
                self.phone: self.formdata.get('phone'), # Full phone
                self.phone0: self.formdata.get('phone0'), # Split phone parts
                self.phone1: self.formdata.get('phone1'),
                self.phone2: self.formdata.get('phone2'),
                self.fax: self.formdata.get('fax'),
                self.address: self.formdata.get('address'), # Full address
                self.address_pref: self.formdata.get('address_pref'), # Specific pref field (text input)
                self.address_city: self.formdata.get('address_city'),
                self.address_thin: self.formdata.get('address_thin'),
                self.zip: self.formdata.get('zip'),
                self.mail: self.formdata.get('mail'),
                self.mail_c: self.formdata.get('mail'), # Confirmation email usually gets the same primary mail
                self.subjects: self.formdata.get('subjects'),
                self.body: self.formdata.get('body'),
                self.url_field_name: self.formdata.get('url') # For website URL field
            }

            for field_html_name, value_to_fill in field_to_data_map.items():
                if field_html_name and value_to_fill: # Ensure HTML field name and data value exist
                    try:
                        # Wait for elements to be present, then filter for interactable ones
                        elements_found = WebDriverWait(driver, 3).until(
                            EC.presence_of_all_elements_located((By.NAME, field_html_name))
                        )
                        target_element_to_fill = None
                        for el_fill in elements_found: # Find first visible and enabled element
                            if el_fill.is_displayed() and el_fill.is_enabled():
                                target_element_to_fill = el_fill; break
                        
                        if target_element_to_fill:
                            tag_name = target_element_to_fill.tag_name
                            element_type_attr = target_element_to_fill.get_attribute("type")
                            # Fill standard input fields (text, email, tel, etc.) and textareas
                            if tag_name == "input" and element_type_attr not in ["radio", "checkbox", "submit", "button", "hidden", "file", "image"]:
                                target_element_to_fill.clear()
                                target_element_to_fill.send_keys(value_to_fill)
                            elif tag_name == "textarea":
                                target_element_to_fill.clear()
                                target_element_to_fill.send_keys(value_to_fill)
                            elif tag_name == "select": # Handle select if logicer mapped it to a text value
                                select_obj_fill = Select(target_element_to_fill)
                                try: select_obj_fill.select_by_visible_text(value_to_fill)
                                except NoSuchElementException:
                                    try: select_obj_fill.select_by_value(value_to_fill)
                                    except NoSuchElementException: print(f"Could not select '{value_to_fill}' for select '{field_html_name}'")
                            # print(f"Filled/Selected in '{field_html_name}'")
                    except TimeoutException:
                        pass # Field not found or not ready in time
                    except Exception as e_fill_one_field:
                        print(f"Error filling field '{field_html_name}': {type(e_fill_one_field).__name__} - {e_fill_one_field}")

            # Specific handling for Prefecture if self.pref is identified as a select element by logicer
            if self.pref and self.formdata.get('address_pref_value'): # Assuming formdata provides a clear value for selection
                try:
                    pref_elements_list = WebDriverWait(driver, 3).until(EC.presence_of_all_elements_located((By.NAME, self.pref)))
                    pref_select_element = next((el for el in pref_elements_list if el.is_displayed() and el.is_enabled() and el.tag_name == "select"), None)
                    if pref_select_element:
                        select_obj_pref = Select(pref_select_element)
                        pref_value_from_data = self.formdata['address_pref_value']
                        try: select_obj_pref.select_by_visible_text(pref_value_from_data)
                        except NoSuchElementException:
                            try: select_obj_pref.select_by_value(pref_value_from_data)
                            except NoSuchElementException: print(f"Could not select prefecture '{pref_value_from_data}' for {self.pref}")
                except Exception as e_pref_select_err: print(f"Error with prefecture select '{self.pref}': {e_pref_select_err}")

            # Agreement Checkbox (self.kiyakucheck identified by logicer)
            if self.kiyakucheck and self.kiyakucheck.get('name'):
                kiyaku_checkbox_name = self.kiyakucheck['name']
                try:
                    # Try by NAME first
                    checkbox_elements = WebDriverWait(driver, 5).until(
                        EC.presence_of_all_elements_located((By.NAME, kiyaku_checkbox_name))
                    )
                    # Fallback to ID if name search fails or yields no elements
                    if not checkbox_elements: 
                        checkbox_elements_by_id = WebDriverWait(driver, 2).until(EC.presence_of_all_elements_located((By.ID, kiyaku_checkbox_name)))
                        if checkbox_elements_by_id: checkbox_elements.extend(checkbox_elements_by_id) # Combine if found by ID
                    
                    for chk_box_el in checkbox_elements: # Iterate through found elements
                        if chk_box_el.is_displayed() and chk_box_el.is_enabled() and not chk_box_el.is_selected():
                            driver.execute_script("arguments[0].scrollIntoView({block: 'center'});", chk_box_el) # Scroll into view
                            time.sleep(0.3)
                            try: chk_box_el.click() # Standard click
                            except ElementClickInterceptedException: driver.execute_script("arguments[0].click();", chk_box_el) # JS click if intercepted
                            print(f"Clicked agreement checkbox: '{kiyaku_checkbox_name}'")
                            break # Clicked one, assume it's done
                except Exception as e_kiyaku_checkbox_err: print(f"Error clicking agreement checkbox '{kiyaku_checkbox_name}': {e_kiyaku_checkbox_err}")
            
            time.sleep(0.5) # Pause before trying to submit

            # --- CAPTCHA Check Before Attempting Submission ---
            if check_for_captcha(driver):
                print("CAPTCHA detected before attempting submission.")
                return {"status": "NG", "reason": "captcha_detected_before_submit_unsolvable"}

            # --- Submission Process (Confirm then Submit, or Direct Submit) ---
            # Common texts for confirm/next buttons
            confirm_button_texts_list = ['確認画面へ', '確認する', '内容確認', '次へ', '進む', '入力内容の確認', 'Confirm', 'Next', 'Continue', 'Preview', '確認', '入力内容を確認する']
            # Common texts for final submit buttons
            submit_button_texts_list = ['送信する', '登録する', '申し込む', 'この内容で送信', '上記内容で送信', 'Submit', 'Send', 'Register', 'Complete', '送信', '上記に同意して送信', 'この内容で登録', 'この内容で申し込む']
            
            clicked_confirm_button = click_button_by_text(driver, confirm_button_texts_list)
            
            if clicked_confirm_button: # If a confirm/next button was clicked
                print("On confirmation page (assumed).")
                time.sleep(1.5) # Wait for confirmation page to load
                if check_error_messages(driver): # Check for errors on confirm page
                    return {"status": "NG", "reason": "error_on_confirmation_page"}
                if check_for_captcha(driver): # Check for CAPTCHA on confirm page
                    return {"status": "NG", "reason": "captcha_on_confirmation_page_unsolvable"}
                
                # Attempt to click the final submit button
                clicked_final_submit_button = click_button_by_text(driver, submit_button_texts_list)
                if not clicked_final_submit_button:
                    print("No distinct final submit button clicked after confirm. Checking for success anyway...")
            else: # No confirm button found/clicked, attempt direct submission
                print("No confirm button found/clicked, attempting direct submission.")
                clicked_direct_submit_button = click_button_by_text(driver, submit_button_texts_list)
                if not clicked_direct_submit_button:
                    # If no submit button, check if we are already on a success page (e.g. single-step AJAX form)
                    if check_success_messages(driver, initial_url, initial_title):
                         return {"status": "OK", "reason": "submission_successful_single_step_form_no_button_click"}
                    return {"status": "NG", "reason": "submit_button_not_found_on_form"}

            # --- Final Success/Failure Check After Submission Attempt ---
            if check_success_messages(driver, initial_url, initial_title):
                return {"status": "OK", "reason": "submission_successful_message_detected"}
            elif check_error_messages(driver): # Check for errors again after final submit attempt
                return {"status": "NG", "reason": "error_message_after_final_submission_attempt"}
            else: # Outcome is unclear
                current_url_after_submit = driver.current_url
                # Check if URL changed significantly to a non-error/form page
                if initial_url.split('?')[0] != current_url_after_submit.split('?')[0] and \
                   not any(kw in current_url_after_submit.lower() for kw in ["error", "fail", "contact", "inquiry", "form", "regist", "confirm", "check", "入力"]):
                    print(f"URL changed significantly from '{initial_url}' to '{current_url_after_submit}' with no explicit errors. Assuming success.")
                    return {"status": "OK", "reason": "url_changed_no_errors_detected_assuming_success"}
                return {"status": "NG", "reason": "submission_outcome_unclear_no_definitive_success_or_error_message"}

        except TimeoutException as e_timeout_main_scope:
            print(f"TimeoutException in go_selenium main scope: {e_timeout_main_scope}")
            traceback.print_exc()
            return {"status": "NG", "reason": f"selenium_timeout_main_scope: {str(e_timeout_main_scope)}"}
        except (SessionNotCreatedException, WebDriverException) as e_webdriver_init_main_scope: # Catch WebDriver startup issues
            print(f"WebDriver/Session Creation Exception in go_selenium: {e_webdriver_init_main_scope}")
            traceback.print_exc() # Print full traceback for these critical errors
            # Provide a more specific reason for these common startup failures
            reason_str = f"webdriver_session_error: {type(e_webdriver_init_main_scope).__name__} - {str(e_webdriver_init_main_scope)[:150]}"
            if "DevToolsActivePort" in str(e_webdriver_init_main_scope):
                reason_str = "webdriver_error_devtools_port_file_missing"
            elif "session not created" in str(e_webdriver_init_main_scope).lower() or "chrome not reachable" in str(e_webdriver_init_main_scope).lower():
                reason_str = "webdriver_error_session_not_created_chrome_unreachable"
            return {"status": "NG", "reason": reason_str}
        except Exception as e_general_main_scope: # Catch any other exceptions
            current_url_at_error = "unknown_url (driver not available or error before navigation)"
            if driver:
                try: current_url_at_error = driver.current_url # Get URL if driver exists
                except: pass # Driver might be dead or unresponsive
            print(f"General error in go_selenium on URL {current_url_at_error}: {type(e_general_main_scope).__name__} - {e_general_main_scope}")
            traceback.print_exc()
            return {"status": "NG", "reason": f"exception_in_go_selenium: {str(e_general_main_scope)[:100]} at {current_url_at_error}"}
        finally:
            if driver: # Always ensure WebDriver is quit
                print("Quitting WebDriver.")
                driver.quit()
                

def run_test_case(url, form_data, log_prefix="test"):
    try:
        logging.info(f"{log_prefix} | Starting test for URL: {url}")
        automation_instance = Place_enter(url, form_data)
        if not automation_instance.form:
            logging.warning(f"{log_prefix} | No form detected, skipping URL: {url}")
            return False
        result = automation_instance.go_selenium()
        status = result.get('status')
        reason = result.get('reason')
        if status == "OK":
            logging.info(f"{log_prefix} | SUCCESS | {url} | {reason}")
            return True
        else:
            logging.warning(f"{log_prefix} | FAIL | {url} | {reason}")
            return False
    except Exception as ex:
        logging.error(f"{log_prefix} | ERROR | {url} | {str(ex)}")
        logging.error(traceback.format_exc())
        return False

def main(test_cases_file="test_cases.json", logs_file="logs.txt"):
    logging.basicConfig(
        level=logging.INFO,
        filename=logs_file,
        filemode='w',
        format='%(asctime)s %(levelname)s: %(message)s'
    )
    # Log to console too
    console = logging.StreamHandler()
    console.setLevel(logging.INFO)
    formatter = logging.Formatter('%(asctime)s %(levelname)s: %(message)s')
    console.setFormatter(formatter)
    logging.getLogger('').addHandler(console)

    # Read test cases
    with open(test_cases_file, "r", encoding="utf-8") as f:
        test_cases = json.load(f)
    total = len(test_cases)
    passed = 0

    for i, case in enumerate(test_cases, 1):
        url = case["url"]
        form_data = case["form_data"]
        log_prefix = f"TestCase-{i:02d}/{total}"
        success = run_test_case(url, form_data, log_prefix=log_prefix)
        if success:
            passed += 1
        # Pause to avoid server rate-limiting
        time.sleep(2)

    score = 100 * passed / total if total else 0
    logging.info(f"\n{'='*40}\nTotal Cases: {total}, Successes: {passed}, Score: {score:.1f}%\n{'='*40}\n")
    # Write score at the end of logs
    with open(logs_file, "a", encoding="utf-8") as f:
        f.write(f"\n{'='*40}\nTotal Cases: {total}, Successes: {passed}, Score: {score:.1f}%\n{'='*40}\n")
    print(f"Final Success Score: {score:.1f}% (see {logs_file})")

if __name__ == "__main__":
    # Usage: python hardware.py test_cases.json logs.txt
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("test_cases_file", nargs="?", default="test_cases.json")
    parser.add_argument("logs_file", nargs="?", default="logs.txt")
    args = parser.parse_args()
    main(args.test_cases_file, args.logs_file)

#switch = 1 #debug mode


# switch = 0

# if switch == 0:
#     print("本番モード")
# elif switch == 1:
#     form_data = {
#         "company":"Tamagawa",
#         "company_kana":"たまがわ",
#         "manager":"多摩川 フラン",
#         "manager_kana":"タマガワ フラン",
#         "phone":"090-3795-5760",
#         "fax":"",
#         "address":"東京都目黒区中目黒", # Consider adding a prefecture for self.pref testing
#         "mail":"info@tamagawa.com",
#         "subjects":"システム開発のご相談", # Test subject
#         "body":"はじめまして。 たまがわと申します。\nこの度、貴社のウェブサイトを拝見し、システム開発についてご相談させて頂きたくご連絡いたしました。\nよろしくお願いいたします。" # Test body
#     }
#     # url = "https://ri-plus.jp/contact"
#     # url = "https://www.amo-pack.com/contact/index.html"

#     print(f"--- Debug Mode Activated for URL: {url} ---")
#     try:
#         # Instantiate Place_enter with the debug data
#         # This assumes your Place_enter.__init__ is ready to parse the form
#         # and logicer correctly identifies fields.
#         automation_instance = Place_enter(url, form_data)

#         # Check if form parsing was successful (optional, depends on your __init__)
#         if not automation_instance.form:
#             print("DEBUG: Place_enter failed to find or initialize the form. Exiting debug run.")
#         else:
#             print(f"DEBUG: Place_enter initialized. Identified field names (examples):")
#             print(f"  Company field name: {automation_instance.company}")
#             print(f"  Manager field name: {automation_instance.manager}")
#             print(f"  Email field name: {automation_instance.mail}")
#             print(f"  Email Confirm field name: {automation_instance.mail_c}")
#             print(f"  Body field name: {automation_instance.body}")
#             print(f"  Kiyaku checkbox name: {automation_instance.kiyakucheck.get('name') if automation_instance.kiyakucheck else 'Not identified'}")
#             # print(f"  Namelist from logicer: {automation_instance.namelist}") # Can be very verbose

#             # Call the go_selenium method
#             print("DEBUG: Calling go_selenium...")
#             result = automation_instance.go_selenium()

#             # Print the result
#             print(f"--- Debug Mode Selenium Result ---")
#             print(f"Status: {result.get('status')}")
#             print(f"Reason: {result.get('reason')}")

#     except Exception as e_debug:
#         print(f"--- Debug Mode Error ---")
#         print(f"An error occurred during the debug run: {e_debug}")
#         traceback.print_exc()

#     print(f"--- Debug Mode Finished ---")