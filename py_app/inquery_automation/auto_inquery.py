import re
#from tkinter.messagebox import NO
from bs4.element import ResultSet
from flask import json
from selenium.webdriver.remote.webelement import WebElement
import inquery_automation
from browser import Browser
import time
from contact_info import ContactInfo
import requests
from typing import List, Optional, Tuple,Dict

from inquery_automation import browser
import datetime

DISC_SUCCESS=0
DISC_NOT_FOUND_INQUERY=1
DISC_CANNOT_ENTER_FORM = 2

# 自動問い合わせを実施するクラス
class AutoInquery(Browser):
    def __init__(self):
        super().__init__();
    def __del__(self):
        super().__del__();
    # 自動問い合わせの実施
    def auto_inquery(self,contact_info:ContactInfo) -> Tuple[bool, int,str]:
        inquery_page_url,result = self.identify_inquery_page(contact_info=contact_info)
        if not result or inquery_page_url == None:
            return self.create_json_from_auto_inquery_result(result=False,disc=DISC_NOT_FOUND_INQUERY,url=None)

        result , disc = self.enter_form(url=inquery_page_url,contact_info=contact_info)
        if not result:
            return self.create_json_from_auto_inquery_result(result=False,disc=disc,url=inquery_page_url)
        return self.create_json_from_auto_inquery_result(result=True,disc=DISC_SUCCESS,url=inquery_page_url)

    # 問い合わせ結果をjsonにまとめる
    def create_json_from_auto_inquery_result(self,result:bool,disc:int,url:Optional[str]) -> json:
        result_json_data =  'OK' if result else 'NG'
        disc_json_data = ""
        if disc == DISC_SUCCESS:
            disc_json_data = "SUCCESS"
        elif disc == DISC_NOT_FOUND_INQUERY:
            disc_json_data = "NG:I can't find inquery page."
        elif disc == DISC_CANNOT_ENTER_FORM:
            disc_json_data = "NG:I can't enter form."
        else:
            disc_json_data = "NG:Unkown"

        data = {
            "date": datetime.datetime.today(),
            "result":result_json_data,
            "discription" : disc_json_data,
            "discription_code": disc,
            "url":url
        }
        return json.dumps(data)

    # 問い合わせページの特定
    def identify_inquery_page(self,contact_info:ContactInfo) -> Tuple[Optional[str], bool]:
        urls = self.create_inquery_page_options(url=contact_info.to_url,to_company=contact_info.to_company)
        for url in set(urls):
            result = self.is_inquery_page(contact_info=contact_info,url=url)
            if result:
                return url,True
        return None,False

    # 問い合わせページの候補作成
    def create_inquery_page_options(self,url:str,to_company:str) -> List[str]:

        page_url_options = []
        result_page_url_options = []
        inquery_words = ["inquiry","inquiries", "contact", "contact_us","contact-us", "information","form"]
        if not url.endswith("/"):
            url += "/"

        # URLに特定の検索メソッド文字列を追加したものを候補に入れる
        for inquery_word in inquery_words:
            page_url_options.append(url + inquery_word)

        # google 検索のトップページの結果を候補に追加
        serch_words = [to_company,"問い合わせ","フォーム"]
        # serch_words.append(to_company,"問い合わせ","フォーム")
        page_url_options.extend(self.google_serch(serch_words=serch_words))

		# ホームページに問い合わせ等の文字列を含むリンクのhrefを利用する
        inquery_link_from_top_page = self.get_inquery_link_from_top_page(url)
        if inquery_link_from_top_page != None:
            page_url_options.append(inquery_link_from_top_page)

        # ページが有効なもののみ結果を返す。
        for page_url in page_url_options:
            if self.is_page_status_ok(page_url):
                result_page_url_options.append(page_url)
        return result_page_url_options

    # ページが存在するか判定
    def is_page_status_ok(self,url:str):
        res = requests.get(url)
        if res.status_code < 300:
            return True
        return False

    # ホームページに問い合わせ等の文字列を含むリンクのhrefを利用する
    def get_inquery_link_from_top_page(self,url:str) -> Optional[str]:
        self.get_access(url)
        inqury_words = ["お問い合わせ","お問い合わせはこちら","問い合わせフォーム","コンタクトフォーム"]
        for word in inqury_words:
            xpath='//a[contains(text(),"' + word + '")]'
            elem = self.get_element_by_xpath(xpath=xpath)
            if elem != None:
                try:
                    return elem.get_attribute("href")
                except:
                    return None

        return None

    # 問い合わせページかどうか判定
    def is_inquery_page(self,contact_info:ContactInfo,url:str):
        if url.startswith(contact_info.to_url):
            self.get_access(url)
            result = True if self.get_element_by_contain_text(text=contact_info.to_company) != None else False
            _ ,submit_btn_result = self.get_form_elems_from_page()

            return result or submit_btn_result
            # return submit_btn_result
        return False

    # 問い合わせページに記入
    def enter_form(self,url:str,contact_info:ContactInfo) -> Tuple[bool, int]:
        self.get_access(url)
        form_elems,result = self.get_form_elems_from_page()

        if not result:
            return result,DISC_CANNOT_ENTER_FORM
        try:
            print(form_elems.keys())
            print(form_elems)
            for elem_key in form_elems.keys():
                if elem_key != "submit":
                    if form_elems[elem_key] != None:
                        print("form_elems")
                        print(form_elems[elem_key].get_attribute('outerHTML'))
                        self.enter_text_to_elem(text= str(getattr(
                            contact_info, elem_key)) ,
                            elem=form_elems[elem_key]
                        )
        except Exception as e:
                print(e)

        result = self.click_elem(elem=form_elems['submit'])
        if result:
            return True,DISC_SUCCESS

        return False,DISC_CANNOT_ENTER_FORM

    # ページ内のフォームで利用できる記入欄を返却
    def get_form_elems_from_page(self) -> Tuple[Dict[str,Optional[WebElement]],bool]:
        form_elems:Dict[str,Optional[WebElement]] =  {
            'from_company': None,
            'kana':None,
            'post':None,
            'address':None,
            'from_url':None,
            'age':None,
            'title':None,
            'person': None,
            'from_tel': None,
            'from_mail': None,
            'content': None,
            'submit': None
        }
        form_attr_list:Dict[str,Dict[str,List[str]]] =  {
            'from_company': {
                                "input_name_list":["company"],
                                "table_label_list":["会社名"]
                            },
            'kana': {
                                "input_name_list":["kana"],
                                "table_label_list":["かな" , "カナ"]
                            },
            'post': {
                                "input_name_list":["post"],
                                "table_label_list":["郵便番号" , "〒"]
                            },
            'address': {
                                "input_name_list":["address", "prefecture"],
                                "table_label_list":["都道府県" , "住所"]
                            },
            'from_url': {
                                "input_name_list":["url" , "hp"],
                                "table_label_list":["ホームページURL"]
                            },
            'age': {
                                "input_name_list":["age"],
                                "table_label_list":["年齢"]
                            },
            'title': {
                                "input_name_list":["title","head","headline"],
                                "table_label_list":["件名"]
                            },
            'person':       {
                                "input_name_list": ["name","manager","person","president"],
                                "table_label_list":["担当者","お名前","名前"]
                            },
            'from_tel':     {
                                "input_name_list": ["phone" , "tel" , "mobile"],
                                "table_label_list":["電話番号" , "携帯番号"]
                            },
            'from_mail':   {
                                "input_name_list": ["email" , "mail" , "e-mail"],
                                "table_label_list":["メール" , "メールアドレス"]
                            },
            'content':      {
                                "input_name_list": ["body" , "inquiry" , "content" , "contents" , "text"],
                                "table_label_list":["本文" , "その他" , "要望" , "問い合わせ"  , "内容"]
                            },
            'submit':       {
                                "submit_type_list": ["submit"]
                            },
        }

        for form_key in form_elems.keys():
            if form_key == 'submit':
                form_elems[form_key] = self.get_from_submit_btn_elem_from_page(
                    submit_type_list=form_attr_list[form_key]["submit_type_list"]
                )
            elif form_key == 'content':
                elem = None
                elem = self.get_from_input_elem_from_page(
                    input_name_list=form_attr_list[form_key]["input_name_list"],table_label_list=form_attr_list[form_key]["table_label_list"]
                )
                if elem == None:
                    elem = self.get_from_textarea_elem_from_page(
                        input_name_list=form_attr_list[form_key]["input_name_list"],table_label_list=form_attr_list[form_key]["table_label_list"]
                    )
                form_elems[form_key] = elem
            else:
                form_elems[form_key] = self.get_from_input_elem_from_page(
                    input_name_list=form_attr_list[form_key]["input_name_list"],table_label_list=form_attr_list[form_key]["table_label_list"]
                )
        print(form_elems)
        result = False
        if form_elems['submit'] != None:
            result = True
        return form_elems,result

    # ページ内のフォームの記入欄を返却
    def get_from_input_elem_from_page(self,input_name_list:List[str],table_label_list:List[str]) -> Optional[WebElement]:

        for input_name in input_name_list:
            elem = self.get_input_element_by_name(name=input_name)
            if elem != None:
                return elem
            print("tr elem")
        for table_label in table_label_list:
            xpath='//tr/*[contains(text(),"' + table_label + '")]'
            result = self.get_element_by_xpath(xpath=xpath)

            if result == None:
                continue
            print(result.get_attribute("outerHTML"))
            parent = self.get_element_by_xpath(xpath="..",from_elem=result)
            if parent == None:
                continue
            result = self.get_element_by_tag_name(tag_name="input",from_elem=parent)
            if result == None:
                continue
            return result


        # tr_elems = self.get_elements_by_tag_name(tag_name="tr")
        # if tr_elems == None:
        #     return None
        # for tr_elem in tr_elems:
        #     print("tr elem")
        #     print(tr_elem.get_attribute("outerHTML"))
        #     for table_label in table_label_list:
        #         xpath='//th[contains(text(),"' + table_label + '")]'
        #         result = self.get_element_by_xpath(xpath=xpath,from_elem=tr_elem)

        #         if result == None:
        #             continue
        #         print(result.get_attribute("outerHTML"))

        #         result =  self.get_element_by_tag_name(tag_name="input",from_elem=tr_elem)
        #         if result == None:
        #             continue
        #         print("get_from_input_elem_from_page")
        #         print(result.get_attribute("outerHTML"))
        #         return result
        return None
    # ページ内のフォームの記入欄を返却
    def get_from_textarea_elem_from_page(self,input_name_list:List[str],table_label_list:List[str]) -> Optional[WebElement]:

        for input_name in input_name_list:
            elem = self.get_input_element_by_name(name=input_name)
            if elem != None:
                return elem
            print("tr elem")
        for table_label in table_label_list:
            xpath='//tr/*[contains(text(),"' + table_label + '")]'
            result = self.get_element_by_xpath(xpath=xpath)

            if result == None:
                continue
            print(result.get_attribute("outerHTML"))
            parent = self.get_element_by_xpath(xpath="..",from_elem=result)
            if parent == None:
                continue
            result = self.get_element_by_tag_name(tag_name="textarea",from_elem=parent)
            if result == None:
                continue
            return result


        # tr_elems = self.get_elements_by_tag_name(tag_name="tr")
        # if tr_elems == None:
        #     return None
        # for tr_elem in tr_elems:
        #     print("tr elem")
        #     print(tr_elem.get_attribute("outerHTML"))
        #     for table_label in table_label_list:
        #         xpath='//th[contains(text(),"' + table_label + '")]'
        #         result = self.get_element_by_xpath(xpath=xpath,from_elem=tr_elem)

        #         if result == None:
        #             continue
        #         print(result.get_attribute("outerHTML"))

        #         result =  self.get_element_by_tag_name(tag_name="input",from_elem=tr_elem)
        #         if result == None:
        #             continue
        #         print("get_from_input_elem_from_page")
        #         print(result.get_attribute("outerHTML"))
        #         return result
        return None

    # ページ内のサブミットボタンを提出
    def get_from_submit_btn_elem_from_page(self,submit_type_list:List[str]) -> Optional[WebElement]:
        for type in submit_type_list:
            elem = self.get_btn_element_by_type(type=type)
            # elem = self.get_btn_element_by_name(name=name)
            if elem != None:
                return elem
        return None
