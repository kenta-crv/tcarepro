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
options.headless = True
start = time.perf_counter()
serv = Service(ChromeDriverManager().install())

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

        self.chk = []


        #BS4データ
        req = requests.get(self.endpoint)
        self.pot = BeautifulSoup(req.text,"lxml")

        #formスキャン
        self.form = self.target_form()
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
        
        #formの中はtableなのか??
        tbl = self.target_table()
        if tbl == 0:
            dtdl = self.target_dtdl()
            if dtdl == 0:
                print('dtdl not found')
                namelist = []
                try:
                    for lbl in self.form.find_all('span'):
                        try:
                            for input in lbl.find_all('input'):
                                data = {}
                                if input['type'] == 'radio' or input['type'] == 'checkbox':
                                    data = {'object':'input','name':input['name'],'type':input['type'],'value':input['value'],'placeholder':input['placeholder']}
                                elif input['type'] == 'hidden':
                                    data = {'object':'hidden'}
                                else:
                                    try:
                                        data = {'object':'input','name':input['name'],'type':input['type'],'value':input['value'],'placeholder':input['placeholder']}
                                    except Exception as e:
                                        data = {'object':'input','name':input['name'],'type':input['type']}
                                namelist.append(data)
                        except Exception as e:
                            print('SKIP')
                            print(e,'input')
                except Exception as e:
                    print(e)

                try:
                    for lbl in self.form.find_all('div'):
                        try:
                            for input in lbl.find_all('input'):
                                data = {}
                                if input['type'] == 'radio' or input['type'] == 'checkbox':
                                    data = {'object':'input','name':input['name'],'type':input['type'],'value':input['value']}
                                elif input['type'] == 'hidden':
                                    data = {'object':'hidden'}
                                else:
                                    try:
                                        data = {'object':'input','name':input['name'],'type':input['type'],'value':input['value'],'placeholder':input['placeholder']}
                                    except Exception as e:
                                        data = {'object':'input','name':input['name'],'type':input['type']}
                                namelist.append(data)
                        except Exception as e:
                            print('SKIP')
                            print(e,'input')
                except Exception as e:
                    print(e)


                try:
                    for lbl in self.form.find_all('span'):
                        try:
                            for textarea in lbl.find_all('textarea'):
                                try:
                                    data = {'object':'textarea','name':textarea['name'],'class':textarea['class']}
                                    namelist.append(data)
                                except Exception as e:
                                    data = {'object':'textarea','name':textarea['name']}
                                    namelist.append(data)
                        except Exception as e:
                            print('SKIP')
                            print(e,'txarea')
                except Exception as e:
                    print(e)

                try:
                    for lbl in self.form.find_all('div'):
                        try:
                            for textarea in lbl.find_all('textarea'):
                                try:
                                    data = {'object':'textarea','name':textarea['name'],'class':textarea['class']}
                                    namelist.append(data)
                                except Exception as e:
                                    data = {'object':'textarea','name':textarea['name']}
                                    namelist.append(data)
                        except Exception as e:
                            print('SKIP')
                            print(e,'textarea')
                except Exception as e:
                    print(e)

                try:
                    for lbl in self.form.find_all('span'):
                        try:
                            for select in lbl.find_all('select'):
                                try:
                                    data = {'object':'select','name':select['name'],'class':select['class']}
                                    namelist.append(data)
                                    for option in select.find_all('option'):
                                        data = {'object':'option','link':select['name'],'class':option['class'],'value':option['value']}
                                        namelist.append(data)
                                except Exception as e:
                                    data = {'object':'select','name':select['name']}
                                    namelist.append(data)
                                    for option in select.find_all('option'):
                                        data = {'object':'option','link':select['name'],'class':option['class'],'value':option['value']}
                                        namelist.append(data)
                        except Exception as e:
                            print('SKIP')
                            print(e,'select error')
                except Exception as e:
                    print(e)

                try:
                    for lbl in self.form.find_all('div'):
                        try:
                            for select in lbl.find_all('select'):
                                try:
                                    data = {'object':'select','name':select['name'],'class':select['class']}
                                    namelist.append(data)
                                    for option in select.find_all('option'):
                                        data = {'object':'option','link':select['name'],'class':option['class'],'value':option['value']}
                                        namelist.append(data)
                                except Exception as e:
                                    data = {'object':'select','name':select['name']}
                                    namelist.append(data)
                                    for option in select.find_all('option'):
                                        data = {'object':'option','link':select['name'],'value':option['value']}
                                        namelist.append(data)
                        except Exception as e:
                            print('SKIP')
                            print(e,'select error')
                except Exception as e:
                    print(e)

                

                self.logicer(namelist)

                self.namelist = namelist


            else:
                namelist = []
                print('Read')

                try:
                    for dx in dtdl:
                        try:
                            for dd in dx.find_all('dd'):
                                try:
                                    for input in dd.find_all('input'):
                                        data = {}
                                        if input['type'] == 'radio' or input['type'] == 'checkbox':
                                            data = {'object':'input','name':input['name'],'type':input['type'],'value':input['value']}
                                        elif input['type'] == 'hidden':
                                            data = {'object':'hidden'}
                                        else:
                                            try:
                                                data = {'object':'input','name':input['name'],'type':input['type'],'value':input['value'],'placeholder':input['placeholder']}
                                            except Exception as e:
                                                data = {'object':'input','name':input['name'],'type':input['type']}
                                        namelist.append(data)
                                except Exception as e:
                                        print('SKIP')
                                        print(e,'input')
                        except Exception as e:
                            print(e)

                        try:
                            for dd in dx.find_all('dd'):
                                try:
                                    for textarea in dd.find_all('textarea'):
                                        try:
                                            data = {'object':'textarea','name':textarea['name'],'class':textarea['class']}
                                            namelist.append(data)
                                        except Exception as e:
                                            data = {'object':'textarea','name':textarea['name']}
                                            namelist.append(data)
                                except Exception as e:
                                        print('SKIP')
                                        print(e,'input')
                        except Exception as e:
                            print(e)

                        try:
                            for dd in dx.find_all('dd'):
                                try:
                                    for select in dd.find_all('select'):
                                        try:
                                            data = {'object':'select','name':select['name'],'class':select['class']}
                                            namelist.append(data)
                                            for option in select.find_all('option'):
                                                data = {'object':'option','link':select['name'],'value':option['value']}
                                                namelist.append(data)
                                        except Exception as e:
                                            data = {'object':'select','name':select['name']}
                                            namelist.append(data)
                                            for option in select.find_all('option'):
                                                data = {'object':'option','link':select['name'],'value':option['value']}
                                                namelist.append(data)
                                except Exception as e:
                                        print('SKIP')
                                        print(e,'input')
                        except Exception as e:
                            print(e)

                except Exception as e:
                    print(e)
                        
                    


                self.logicer(namelist)

                self.namelist = namelist



        else:
            tables = tbl
            namelist = []
            i = 0
            j = 0
            k = 0
            try:
                    try:
                        try:
                            if tables.find_all('tbody') == 0:
                                print("tbody is not.")
                            
                            print(tables.find_all('input'))
                            print(i)
                            for input in tables.find_all('input'):
                                data = {}
                                if input['type'] == 'radio' or input['type'] == 'checkbox':
                                    data = {'object':'input','name':input['name'],'type':input['type'],'value':input['value']}
                                elif input['type'] == 'hidden':
                                    data = {'object':'hidden'}
                                else:
                                    try:
                                        data = {'object':'input','name':input['name'],'type':input['type'],'value':input['value'],'placeholder':input['placeholder']}
                                    except Exception as e:
                                        data = {'object':'input','name':input['name'],'type':input['type']}
                                namelist.append(data)
                            i += 1   
                        except Exception as e:
                            print('SKIP')
                            print(e)

                        try:
                            print(tables.find_all('span'))
                            for textarea in tables.find_all('textarea'):
                                try:
                                    data = {'object':'textarea','name':textarea['name'],'class':textarea['class']}
                                    namelist.append(data)
                                except Exception as e:
                                    data = {'object':'textarea','name':textarea['name']}
                                    namelist.append(data)
                            print(j)
                            j += 1   
                        except Exception as e:
                            print('SKIP')
                            print(e)

                        try:
                            print(tables.find_all('span'))
                            for select in tables.find_all('select'):
                                try:
                                    data = {'object':'select','name':select['name'],'class':select['class']}
                                    namelist.append(data)
                                    for option in select.find_all('option'):
                                        data = {'object':'option','link':select['name'],'value':option['value']}
                                        namelist.append(data)
                                except Exception as e:
                                    data = {'object':'select','name':select['name']}
                                    namelist.append(data)
                                    for option in select.find_all('option'):
                                        data = {'object':'option','link':select['name'],'value':option['value']}
                                        namelist.append(data)
                            k += 1       
                        except Exception as e:
                            print('SKIP')
                            print(e)

                    except Exception as e:
                        print('SKIP')
                        print(e)

                
            except Exception as e:
                print('ERROR')
                print(e,sys.exc_info()[1])
            

            

                #タグ解析ロジック        
            self.logicer(namelist)

            if self.company == '': ##会社を特定
                for companyies_row in tables.find_all('tr'):
                    for companyies_col in companyies_row.find_all('th'):
                        if '会社' in companyies_col.text or '貴社' in companyies_col.text:
                            td = companyies_row.find('td')
                            ipt = td.find('input')
                            self.company = ipt['name']

            if self.company_kana == '': ##会社ふりがなを特定
                for companyies_row in tables.find_all('tr'):
                    for companyies_col in companyies_row.find_all('th'):
                        if '会社ふりがな' in companyies_col.text or '貴社ふりがな' in companyies_col.text:
                            td = companyies_row.find('td')
                            ipt = td.find('input')
                            self.company_kana = ipt['name']

            if self.manager == '': ##名前を特定
                for companyies_row in tables.find_all('tr'):
                    for companyies_col in companyies_row.find_all('th'):
                        if '名前' in companyies_col.text or '担当者名' in companyies_col.text:
                            td = companyies_row.find('td')
                            ipt = td.find('input')
                            self.manager = ipt['name']

            if self.manager_kana == '': ##名前を特定
                for companyies_row in tables.find_all('tr'):
                    for companyies_col in companyies_row.find_all('th'):
                        if 'ふりがな' in companyies_col.text or 'フリガナ' in companyies_col.text:
                            td = companyies_row.find('td')
                            ipt = td.find('input')
                            self.manager_kana = ipt['name']

            if self.zip == '': ##名前を特定
                for companyies_row in tables.find_all('tr'):
                    for companyies_col in companyies_row.find_all('th'):
                        if '郵便番号' in companyies_col.text:
                            td = companyies_row.find('td')
                            ipt = td.find('input')
                            self.zip = ipt['name']

            if self.address == '': ##住所を特定
                for companyies_row in tables.find_all('tr'):
                    for companyies_col in companyies_row.find_all('th'):
                        if '住所' in companyies_col.text:
                            td = companyies_row.find('td')
                            ipt = td.find('input')
                            self.address = ipt['name']

            if self.pref == '': ##住所(都道府県)を特定
                for companyies_row in tables.find_all('tr'):
                    for companyies_col in companyies_row.find_all('th'):
                        if '都道府県' in companyies_col.text:
                            td = companyies_row.find('td')
                            ipt = td.find('input')
                            if ipt == None:
                                print('OK')
                                slc = td.find('select')
                                self.pref = slc['name']
                            else:
                                self.pref = ipt['name']

            if self.address_city == '': ##住所(市町村)を特定
                for companyies_row in tables.find_all('tr'):
                    for companyies_col in companyies_row.find_all('th'):
                        if '市区町村' in companyies_col.text or '市町村' in companyies_col.text:
                            td = companyies_row.find('td')
                            ipt = td.find('input')
                            self.address_city = ipt['name']

            if self.address_thin == '': ##住所(詳細)を特定
                for companyies_row in tables.find_all('tr'):
                    for companyies_col in companyies_row.find_all('th'):
                        if '番地' in companyies_col.text:
                            td = companyies_row.find('td')
                            ipt = td.find('input')
                            self.address_thin = ipt['name']

            if self.phone == '': ##住所(市町村)を特定
                for companyies_row in tables.find_all('tr'):
                    for companyies_col in companyies_row.find_all('th'):
                        if '電話番号' in companyies_col.text:
                            td = companyies_row.find('td')
                            ipt = td.find('input')
                            
                            self.phone = ipt['name']

            if self.mail == '': ##住所(市町村)を特定
                for companyies_row in tables.find_all('tr'):
                    for companyies_col in companyies_row.find_all('th'):
                        if 'メールアドレス' in companyies_col.text:
                            td = companyies_row.find('td')
                            ipt = td.find('input')
                            
                            self.mail = ipt['name']

            if self.subjects == '': ##xxを特定
                for companyies_row in tables.find_all('tr'):
                    for companyies_col in companyies_row.find_all('th'):
                        if '用件' in companyies_col.text:
                            try:
                                td = companyies_row.find('td')
                                ipt = td.find_all('input')
                                for inpt in ipt:
                                    if inpt['type'] == 'checkbox':
                                        self.subjects_radio_badge = True
                                        self.subjects = inpt['name']
                                    else:
                                        self.subjects = inpt['name']
                            except Exception as e:
                                print('ERROR')
                                print(traceback.format_exc())


            self.namelist = namelist

            


        
        





    def target_form(self):
        for form in self.pot.find_all():
            for forms in form.find_all('form'):
                print(forms)
                try:
                    try:
                        if 'search' in forms['class']:
                            continue
                        else:
                            return forms
                    except Exception as e:
                        if 'search' in forms['id']:
                            continue
                        else:
                            return forms
                except Exception as e:
                    print(e)
                    return forms
            
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
        
    def logicer(self,lists):
        radio = []
        check = []
        for list in lists:
            if list["object"] == "input":
                if list["type"] == "text":
                    if "name" in list["name"] or "名前" in list["name"]:
                        if "furigana" in list["name"] or "hurigana" in list["name"] or "ふりがな" in list["name"] or "kana" in list["name"]:
                            self.manager_kana = list["name"]
                        elif "company" in list["name"]:
                            self.company = list["name"]
                        else:
                            self.manager = list["name"]
                    elif "hurigana" in list["name"] or "furigana" in list["name"] or "フリガナ" in list["name"] or "kana" in list["name"]:
                        if "mei" in list["name"] or "sei" in list["name"]:
                            print("この要素は使わない")
                        else:
                            self.manager_kana = list["name"]
                    elif "sei" in list["name"] or "姓" in list["name"]:
                        self.manager_last = list["name"]
                    elif "mei" in list["name"] or "名" in list["name"]:
                        self.manager_first = list["name"]
                    elif "kana_sei" in list["name"] or "セイ" in list["name"]:
                        self.manager_last_kana = list["name"]
                    elif "kana_mei" in list["name"] or "メイ" in list["name"]:
                        self.manager_first_kana = list["name"]
                    elif "company" in list["name"] or "company_name" in list["name"] or "会社" in list["name"] or "貴社" in list["name"] or "貴社名" in list["name"] or "499" in list["name"] or "御社" in list["name"]:
                        self.company = list["name"]
                    elif "email" in list["name"] or "mail" in list["name"] or "メール" in list["name"]:
                        if "confirm" in list["name"] or "2" in list["name"]:
                            self.mail_c = list["name"]
                        else:
                            self.mail = list["name"]
                    elif "tel[data][0]" in list["name"] or "[data][0]" in list["name"]:
                        if "zip" in list["name"]:
                            print("")
                        else:
                            self.phone0 = list["name"]
                    elif "tel[data][1]" in list["name"] or "[data][1]" in list["name"]:
                        if "zip" in list["name"]:
                            print("")
                        else:
                            self.phone1 = list["name"]
                    elif "tel[data][2]" in list["name"] or "[data][2]" in list["name"]:
                        if "zip" in list["name"]:
                            print("nothing")
                        else:
                            self.phone2 = list["name"]
                    elif "zip" in list["name"]:
                        self.zip = list["name"]
                    elif "tel" in list["name"] or "telephone" in list["name"] or "電話番号" in list["name"]:
                        self.phone = list["name"]
                    elif "address" in list["name"] or "住所" in list["name"] or "addr" in list["name"]:
                        print("anything住所")
                        self.address = list["name"]
                    elif "subject" in list["name"] or "件名" in list["name"] or "タイトル" in list["name"]:
                        self.subjects = list["name"]
                elif list["type"] == "radio":
                    radio.append({"radioname":list["name"],"value":list["value"]})
                elif list["type"] == "checkbox":
                    check.append({"checkname":list["name"],"value":list["value"]})
                    self.chk.append({"checkname":list["name"],"value":list["value"]})
                elif list["type"] == "email":
                    if "mail" in list["name"] or "email" in list["name"] or "メール" in list["name"] or "メールアドレス" in list["name"]:
                        if "confirm" in list["name"]:
                            print("anythingメール確認")
                            self.mail_c = list["name"]
                        else:
                            self.mail = list["name"]
                            print("anythingメール")
                elif list["type"] == "tel":
                    if "tel" in list["name"] or "telephone" in list["name"] or "電話" in list["name"]:
                        self.phone = list["name"]
            elif list["object"] == "textarea":
                print("anything_textarea")
                self.body = list["name"]
            elif list["object"] == "select":
                print("anything_select")
                if "pref" in list["name"]:
                    self.pref = list["name"]
                if "content" in list["name"] or "subject" in list["name"] or "slct2" in list["name"]:
                    self.subjects = list["name"]

        
        for ph in lists:
            try:
                if "せい" in ph["placeholder"]:
                    self.manager_last_kana = ph["name"]
            except Exception as e:
                print("nothing")

        for ph in lists:
            try:
                if "めい" in ph["placeholder"]:
                    self.manager_first_kana = ph["name"]
            except Exception as e:
                print("nothing")

        

        for r in radio:
            if 'answer' in r['radioname'] or 'contact' in r['radioname'] or 'response' in r['radioname']:
                self.response_contact.append({'name':r['radioname'],'value':r['value']})
            elif 'type' in r['radioname']:
                self.industry.append({'name':r['radioname'],'value':r['value']})

        for c in check:
            print(c)
            if '規約' in c['checkname'] or 'privacy' in c['checkname'] or 'kakunin' in c['checkname']:
                self.kiyakucheck['type'] = 'checkbox'
                self.kiyakucheck['name'] = c['checkname']

        
        for form in self.form.find_all('input'):
            try:
                if form['type'] == 'checkbox':
                    if 'agree' in form['name'] or 'check' in form['name'] or 'confirm' in form['name']:
                        self.kiyakucheck['type'] = 'checkbox'
                        self.kiyakucheck['name'] = form['name']
            except Exception as e:
                print("form error")


    def go_selenium(self):
        driver = webdriver.Chrome(service=serv,options=options)
        driver.get(self.endpoint)
        time.sleep(3)

        #form入力　あるもので
        #soup情報

        if self.iframe_mode == True:
            iframe = driver.find_element(By.TAG_NAME,'iframe')
            driver.switch_to.frame(iframe)

            if self.company != '':
                driver.find_element(By.NAME,self.company).send_keys(self.formdata['company'])
        
            if self.company_kana != '':
                driver.find_element(By.NAME,self.company_kana).send_keys(self.formdata['company_kana'])

            if self.manager != '':
                driver.find_element(By.NAME,self.manager).send_keys(self.formdata['manager'])
            elif self.manager_first != '' and self.manager_last != '':
                names = self.formdata['manager'].split('　')
                try:
                    driver.find_element(By.NAME,self.manager_last).send_keys(names[0])
                    driver.find_element(By.NAME,self.manager_first).send_keys(names[1])
                except Exception as e:
                    print("名前エラー")

            if self.manager_kana != '':
                driver.find_element(By.NAME,self.manager_kana).send_keys(self.formdata['manager_kana'])
            elif self.manager_first_kana != '' and self.manager_last_kana != '':
                names = self.formdata['manager_kana'].split('　')
                try:
                    driver.find_element(By.NAME,self.manager_last_kana).send_keys(names[0])
                    driver.find_element(By.NAME,self.manager_first_kana).send_keys(names[1])
                except Exception as e:
                    print("Nameエラー")
                    print(e)

            #普通電話番号
            if self.phone != '':
                driver.find_element(By.NAME,self.phone).send_keys(self.formdata['phone'])

            #分割用電話番号 
            if self.phone0 != '' and self.phone1 != '' and self.phone2 != '':
                phonesplit = self.formdata['phone'].split('-')
                driver.find_element(By.NAME,self.phone0).send_keys(phonesplit[0])
                driver.find_element(By.NAME,self.phone1).send_keys(phonesplit[1])
                driver.find_element(By.NAME,self.phone2).send_keys(phonesplit[2])
        
            if self.fax != '':
                driver.find_element(By.NAME,self.fax).send_keys(self.formdata['fax'])

            if self.address != '':
                driver.find_element(By.NAME,self.address).send_keys(self.formdata['address'])
        
            if self.zip != '':
                r = requests.get("https://api.excelapi.org/post/zipcode?address=" + self.formdata['address'])
                postman = r.text
                driver.find_element(By.NAME,self.zip).send_keys(postman[:3]+ "-" + postman[3:])

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


                for p in pref:
                    if p in address:
                        s = Select(driver.find_element(By.NAME,self.pref))
                        s.select_by_visible_text(p)
                        pref_data = p
                
                

                r = requests.get("https://geoapi.heartrails.com/api/json?method=getTowns&prefecture=" + pref_data)
                cityjs = r.json()
                city = cityjs["response"]["location"]
                print("cityjs")
                for c in city:
                    if c["city"] in address and c["town"] in address:
                        driver.find_element(By.NAME,self.address_city).send_keys(c["city"])
                        driver.find_element(By.NAME,self.address_thin).send_keys(c["town"])
                            

            if self.mail != '':
                driver.find_element(By.NAME,self.mail).send_keys(self.formdata['mail'])

            if self.mail_c != '':
                driver.find_element(By.NAME,self.mail_c).send_keys(self.formdata['mail'])

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

            if self.body != '':
                driver.find_element(By.NAME,self.body).send_keys(self.formdata['body'])

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

            try:
                before = driver.title
                driver.find_element(By.NAME,self.body).submit()
                try:
                    confirm_source = BeautifulSoup(driver.page_source, "lxml").prettify()
                    sourcer = BeautifulSoup(confirm_source, "lxml")
                    for s in sourcer.find_all('input'):
                        if '送信' in s['value']:
                            driver.find_element(By.XPATH,"//input[@value='"+ s['value']+"']").click()

                except Exception as e:
                    print('一度送信')
                time.sleep(3)
                after = driver.title
                driver.close()
                return 'OK'
            
            except Exception as e:
                driver.close()
                return 'NG'
            
        else:



            if self.company != '':
                driver.find_element(By.NAME,self.company).send_keys(self.formdata['company'])
        
            if self.company_kana != '':
                driver.find_element(By.NAME,self.company_kana).send_keys(self.formdata['company_kana'])

            if self.manager != '':
                driver.find_element(By.NAME,self.manager).send_keys(self.formdata['manager'])
            elif self.manager_first != '' and self.manager_last != '':
                names = self.formdata['manager'].split('　')
                try:
                    driver.find_element(By.NAME,self.manager_last).send_keys(names[0])
                    driver.find_element(By.NAME,self.manager_first).send_keys(names[1])
                except Exception as e:
                    print("名前エラー")

            if self.manager_kana != '':
                driver.find_element(By.NAME,self.manager_kana).send_keys(self.formdata['manager_kana'])
            elif self.manager_first_kana != '' and self.manager_last_kana != '':
                names = self.formdata['manager_kana'].split('　')
                try:
                    driver.find_element(By.NAME,self.manager_last_kana).send_keys(names[0])
                    driver.find_element(By.NAME,self.manager_first_kana).send_keys(names[1])
                except Exception as e:
                    print("Nameエラー")
                    print(e)

            #普通電話番号
            if self.phone != '':
                driver.find_element(By.NAME,self.phone).send_keys(self.formdata['phone'])

            #分割用電話番号 
            if self.phone0 != '' and self.phone1 != '' and self.phone2 != '':
                phonesplit = self.formdata['phone'].split('-')
                driver.find_element(By.NAME,self.phone0).send_keys(phonesplit[0])
                driver.find_element(By.NAME,self.phone1).send_keys(phonesplit[1])
                driver.find_element(By.NAME,self.phone2).send_keys(phonesplit[2])
        
            if self.fax != '':
                driver.find_element(By.NAME,self.fax).send_keys(self.formdata['fax'])

            if self.address != '':
                driver.find_element(By.NAME,self.address).send_keys(self.formdata['address'])
        
            if self.zip != '':
                r = requests.get("https://api.excelapi.org/post/zipcode?address=" + self.formdata['address'])
                postman = r.text
                driver.find_element(By.NAME,self.zip).send_keys(postman[:3]+ "-" + postman[3:])

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

                for p in pref:
                    if p in address:
                        s = Select(driver.find_element(By.NAME,self.pref))
                        s.select_by_visible_text(p)
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

            if self.mail != '':
                driver.find_element(By.NAME,self.mail).send_keys(self.formdata['mail'])

            if self.mail_c != '':
                driver.find_element(By.NAME,self.mail_c).send_keys(self.formdata['mail'])

            print(self.subjects)

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

            if self.body != '':
                driver.find_element(By.NAME,self.body).send_keys(self.formdata['body'])

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

            try:
                before = driver.title
                driver.find_element(By.NAME,self.body).submit()
                try:
                    confirm_source = BeautifulSoup(driver.page_source, "lxml").prettify()
                    sourcer = BeautifulSoup(confirm_source, "lxml")
                    for s in sourcer.find_all('input'):
                        if '送信' in s['value']:
                            driver.find_element(By.XPATH,"//input[@value='"+ s['value']+"']").click()

                except Exception as e:
                    print('ERROR')
                time.sleep(3)   
                print('D')
                after = driver.title
                driver.close()
                return 'OK'
            
            except Exception as e:
                driver.close()
                return 'NG'

switch = 0 #debug mode

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
    url = "https://www.amo-pack.com/contact/index.html" 
    p = Place_enter(url,form_data)  
    print(p.go_selenium())



