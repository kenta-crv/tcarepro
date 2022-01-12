from datetime import datetime
from logging import ERROR
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from bs4.element import  Tag
import bs4
import bs4.element
import time
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.remote.webdriver import WebDriver
from selenium.webdriver.remote.webelement import WebElement

from typing import List, Tuple, Dict, Set, Union,Optional

GOOGLE_URL ="https://www.google.com/"
GOOGLE_SERCH_METHOD = "search"
GOOGLE_SERCH_QUERY_HEAD = "?q="
GOOGLE_SERCH_QUERY_DELIMITER= "+"

HTML_TAG_NAME_A = "a"
HTML_ATTR_CLASS_NAME_GOOGLE_SERCH_RESULT="g"

SELENIUM_METHOD_FIND_ELEM_BY_ID="find_element_by_id"
SELENIUM_METHOD_FIND_ELEM_BY_CLASS_NAME="find_element_by_class_name"
SELENIUM_METHOD_FIND_ELEMS_BY_CLASS_NAME="find_elements_by_class_name"
SELENIUM_METHOD_FIND_ELEM_BY_XPATH="find_element_by_xpath"
SELENIUM_METHOD_FIND_ELEM_BY_TAG_NAME="find_element_by_tag_name"
SELENIUM_METHOD_FIND_ELEMS_BY_TAG_NAME="find_elements_by_tag_name"

# Chromeドライバーをインストールするためのクラス
# クラス変数としてドライバを持つ（シングルトン）
class SingleChromeDriver(object):
    _instance = None
    _driver = None
    def __new__(cls, *args, **kwargs):
        if cls._instance is None:
            cls._instance = super().__new__(cls, *args, **kwargs)
            cls._driver = ChromeDriverManager().install()

        return cls._instance

    def get_chrome_driver(self):
        return self._driver

# Chromeブラウザを操作するためのクラス
class Browser:
    driver:WebDriver=None
    _chromedriver:SingleChromeDriver=None
    def __init__(self):
        self._chromedriver=SingleChromeDriver()
        self.driver= webdriver.Chrome(self._chromedriver.get_chrome_driver())

    # グーグル検索の結果を返す
    def google_serch(self,serch_words:List[str]) -> List[str]:
        results = []

        # 検索ワードチェック
        if len(serch_words) == 0:
            return None

        # 検索用URL作成
        search_url = GOOGLE_URL + GOOGLE_SERCH_METHOD + GOOGLE_SERCH_QUERY_HEAD + GOOGLE_SERCH_QUERY_DELIMITER.join(serch_words)

        # 検索
        self.driver.get(search_url)

        # 検索結果取得
        elems = self.get_elements_by_class_name(class_name=HTML_ATTR_CLASS_NAME_GOOGLE_SERCH_RESULT)
        if elems == None:
            return None
        for elem in elems:
            a_elem = self.get_element_by_tag_name(tag_name=HTML_TAG_NAME_A,from_elem=elem)
            if a_elem != None and a_elem.get_attribute("href"):
                results.append(a_elem.get_attribute("href"))
        return results


        
# ==Selenium Wrapper========================================
    def get_element_method_impl(self,attr:str,selenium_method:str,from_elem:Optional[WebElement]=None) -> Union[ Optional[WebElement], Optional[ List[WebElement] ] ] :
        if from_elem == None:
            from_elem = self.driver
        elem = None
        try:
            if selenium_method == SELENIUM_METHOD_FIND_ELEM_BY_ID:
                elem = from_elem.find_element_by_id(attr)
            elif selenium_method == SELENIUM_METHOD_FIND_ELEM_BY_CLASS_NAME:
                elem = from_elem.find_element_by_class_name(attr)
            elif selenium_method == SELENIUM_METHOD_FIND_ELEMS_BY_CLASS_NAME:
                elem = from_elem.find_elements_by_class_name(attr)
            elif selenium_method == SELENIUM_METHOD_FIND_ELEM_BY_XPATH:
                elem = from_elem.find_element_by_xpath(attr)
            elif selenium_method == SELENIUM_METHOD_FIND_ELEM_BY_TAG_NAME:
                elem = from_elem.find_element_by_tag_name(attr)
            elif selenium_method == SELENIUM_METHOD_FIND_ELEMS_BY_TAG_NAME:
                elem = from_elem.find_elements_by_tag_name(attr)
        except:
            elem = None
        return elem

    def get_element_method_impl_wrapper(self,attr:str,selenium_method:str,from_elem:Optional[WebElement]=None,timeup_on:bool = False, timeup_count:int = 5) -> Union[ Optional[WebElement], Optional[ List[WebElement] ] ] :
        elem = self.get_element_method_impl(attr=attr,selenium_method=selenium_method,from_elem=from_elem)
        st_time = time.time()
        if(timeup_on):
            while(elem == None):
                elem = self.get_element_method_impl(attr=attr,selenium_method=selenium_method,from_elem=from_elem)
                if check_time_up(st_time=st_time,interval=timeup_count):
                    break
        return elem

# ==Selenium Get Elements========================================
    # idから要素を取得する
    def get_element_by_id(self,id:str,from_elem:Optional[WebElement]=None) -> Optional[WebElement]:
        return self.get_element_method_impl_wrapper(attr=id,from_elem=from_elem,selenium_method=SELENIUM_METHOD_FIND_ELEM_BY_ID)
    
    # クラス名から複数の要素を取得する
    def get_elements_by_class_name(self,class_name:str,from_elem:Optional[WebElement]=None) -> Optional[List[WebElement]]:
        return self.get_element_method_impl_wrapper(attr=class_name,from_elem=from_elem,selenium_method=SELENIUM_METHOD_FIND_ELEMS_BY_CLASS_NAME)
    
    # クラス名から要素を取得する
    def get_element_by_class_name(self,class_name:str,from_elem:Optional[WebElement]=None) -> Optional[WebElement]:
        return self.get_element_method_impl_wrapper(attr=class_name,from_elem=from_elem,selenium_method=SELENIUM_METHOD_FIND_ELEM_BY_CLASS_NAME)

    # xpathから複数の要素を取得する
    def get_element_by_xpath(self,xpath:str,from_elem:Optional[WebElement]=None) -> Optional[WebElement]:
        return self.get_element_method_impl_wrapper(attr=xpath,from_elem=from_elem,selenium_method=SELENIUM_METHOD_FIND_ELEM_BY_XPATH)

    # 属性nameからinput要素を取得する
    def get_input_element_by_name(self,name:str,from_elem:Optional[WebElement]=None) -> Optional[WebElement]:
        xpath='//input[name=' + name + ']'
        return self.get_element_method_impl_wrapper(attr=xpath,from_elem=from_elem,selenium_method=SELENIUM_METHOD_FIND_ELEM_BY_XPATH)

    def get_div_element_by_contain_text(self,text:str,from_elem:Optional[WebElement]=None) -> Optional[WebElement]:
        xpath='//input[contains(text(),"' + text + '")]'
        return self.get_element_method_impl_wrapper(attr=xpath,from_elem=from_elem,selenium_method=SELENIUM_METHOD_FIND_ELEM_BY_XPATH)

    # htmlタグ名から要素を取得する
    def get_element_by_tag_name(self,tag_name:str,from_elem:Optional[WebElement]=None) -> Optional[WebElement]:
        return self.get_element_method_impl_wrapper(attr=tag_name,from_elem=from_elem,selenium_method=SELENIUM_METHOD_FIND_ELEM_BY_TAG_NAME)

    # htmlタグ名から要素を取得する
    def get_element_by_tag_name(self,tag_name:str,from_elem:Optional[WebElement]=None) -> Optional[WebElement]:
        return self.get_element_method_impl_wrapper(attr=tag_name,from_elem=from_elem,selenium_method=SELENIUM_METHOD_FIND_ELEMS_BY_TAG_NAME)

    # htmlタグ名から名から複数要素を取得する
    def get_elements_by_tag_name(self,tag_name:str,from_elem:Optional[WebElement]=None) -> Optional[WebElement]:
        return self.get_element_method_impl_wrapper(attr=tag_name,from_elem=from_elem,selenium_method=SELENIUM_METHOD_FIND_ELEMS_BY_TAG_NAME)

    # 属性nameからぶっとn要素を取得する
    def get_btn_element_by_name(self,name:str,from_elem:Optional[WebElement]=None) -> Optional[WebElement]:
        xpath='//button[contains(@name="' + name + '")]'
        return self.get_element_method_impl_wrapper(attr=xpath,from_elem=from_elem,selenium_method=SELENIUM_METHOD_FIND_ELEM_BY_XPATH) 

    #要素にテキストを入れる
    def enter_text_to_elem(self,text:str,elem:WebElement):
        if elem != None:
            elem.send_keys(text)
            return True
        return False

    # 要素をクリックする
    def click_elem(self,elem:WebElement) -> bool:
        if elem != None:
            elem.click()
            return True
        return False

    # urlにアクセするう
    def get_access(self,url):
        
        self.driver.get(url);

def check_time_up(self,st_time:datetime,interval:int):
        tim =time.time() - st_time
        if tim > interval:
            return True
        else:
            return False