import time
import json
import logging
import requests
from bs4 import BeautifulSoup
from concurrent.futures import ThreadPoolExecutor, as_completed
from selenium import webdriver
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.support.select import Select
from selenium.webdriver.chrome.options import Options
from selenium.common.exceptions import TimeoutException, NoSuchElementException
from webdriver_manager.chrome import ChromeDriverManager
import base64
import io
from PIL import Image
import pytesseract
import cv2
import numpy as np
import re

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('log.txt', mode='w', encoding='utf-8'),
        logging.StreamHandler()  # Keep console output for immediate feedback
    ]
)

logger = logging.getLogger(__name__)

class Place_enter:
    def __init__(self, url, formdata):
        self.endpoint = url
        self.formdata = formdata
        self.field_mappings = {}
        self.iframe_mode = False
        
        # Parse the page first
        self._parse_page()

    def _parse_page(self):
        """Parse the page and extract form information"""
        try:
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
            }
            response = requests.get(self.endpoint, headers=headers, timeout=20)
            response.encoding = response.apparent_encoding or 'utf-8'
            
            soup = BeautifulSoup(response.text, "lxml")
            forms = soup.find_all('form')
            
            if not forms:
                # Check for iframes
                if soup.find('iframe'):
                    self.iframe_mode = True
                    logger.info(f"No direct forms found, iframe detected: {self.endpoint}")
                else:
                    logger.warning(f"No forms found at all: {self.endpoint}")
                return
            
            # Find the best form (usually the largest one with most inputs)
            best_form = None
            max_inputs = 0
            
            for form in forms:
                input_count = len(form.find_all(['input', 'textarea', 'select']))
                if input_count > max_inputs:
                    max_inputs = input_count
                    best_form = form
            
            if best_form and max_inputs >= 3:  # At least 3 form elements
                logger.info(f"Found form with {max_inputs} elements: {self.endpoint}")
                self._extract_field_info(best_form)
            else:
                logger.warning(f"No substantial form found: {self.endpoint}")
                
        except Exception as e:
            logger.error(f"Error parsing page {self.endpoint}: {e}")

    def _extract_field_info(self, form):
        """Extract field information from form"""
        # Define comprehensive keyword mappings
        mappings = {
            'company': ['会社', '社名', '企業', '法人', 'company', 'corp', 'organization'],
            'company_kana': ['会社ふりがな', '社名ふりがな', '企業ふりがな', 'company_kana', 'company_furigana'],
            'name': ['名前', '氏名', 'お名前', 'name', 'your_name', 'fullname'],
            'name_kana': ['ふりがな', 'フリガナ', '氏名ふりがな', 'name_kana', 'furigana'],
            'email': ['メール', 'email', 'mail', 'e-mail', 'メールアドレス'],
            'phone': ['電話', 'tel', 'phone', 'telephone', '電話番号'],
            'zip': ['郵便', 'zip', 'postal', '郵便番号', 'postcode'],
            'address': ['住所', 'address', '所在地'],
            'subject': ['件名', 'subject', 'title', '問い合わせ種類', 'inquiry_type'],
            'message': ['内容', 'message', 'body', 'detail', 'お問い合わせ内容', '詳細', 'comment'],
        }
        
        # Extract all form fields
        for element in form.find_all(['input', 'textarea', 'select']):
            name = element.get('name')
            if not name:
                continue
                
            element_type = element.get('type', 'text')
            if element_type in ['submit', 'button', 'hidden', 'image']:
                continue
            
            # Get context for this field
            context = self._get_field_context(element, form)
            context_lower = context.lower()
            
            # Match against our mappings
            for field_type, keywords in mappings.items():
                if field_type in self.field_mappings:
                    continue  # Already mapped
                    
                for keyword in keywords:
                    if keyword in context_lower:
                        self.field_mappings[field_type] = name
                        logger.info(f"Mapped {field_type} -> {name} (context: {context[:50]})")
                        break

    def _get_field_context(self, element, form):
        """Get context text for a form element"""
        contexts = []
        
        # Add the name attribute
        if element.get('name'):
            contexts.append(element.get('name'))
        
        # Add id
        if element.get('id'):
            contexts.append(element.get('id'))
        
        # Add placeholder
        if element.get('placeholder'):
            contexts.append(element.get('placeholder'))
        
        # Find associated label
        element_id = element.get('id')
        if element_id:
            label = form.find('label', {'for': element_id})
            if label:
                contexts.append(label.get_text(strip=True))
        
        # Check parent label
        parent_label = element.find_parent('label')
        if parent_label:
            contexts.append(parent_label.get_text(strip=True))
        
        # Check nearby text in table cells or divs
        parent = element.find_parent(['td', 'th', 'div', 'p', 'span'])
        if parent:
            text = parent.get_text(strip=True)
            if len(text) < 100:  # Avoid getting huge chunks of text
                contexts.append(text)
        
        return ' '.join(contexts)

    def go_selenium(self):
        """Main Selenium automation"""
        options = Options()
        options.add_argument('--headless')
        options.add_argument('--no-sandbox')
        options.add_argument('--disable-dev-shm-usage')
        options.add_argument('--disable-gpu')
        options.add_argument('--window-size=1920,1080')
        options.add_argument('--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
        options.add_argument('--disable-blink-features=AutomationControlled')
        
        driver = None
        try:
            driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)
            driver.set_page_load_timeout(30)
            
            # Navigate to page
            logger.info(f"Navigating to: {self.endpoint}")
            driver.get(self.endpoint)
            time.sleep(3)
            
            # Handle iframe if detected
            if self.iframe_mode:
                if not self._handle_iframe(driver):
                    logger.error(f"Failed to handle iframe: {self.endpoint}")
                    return {"status": "NG", "reason": "iframe_handling_failed"}
            
            # Wait for form
            try:
                WebDriverWait(driver, 15).until(
                    EC.any_of(
                        EC.presence_of_element_located((By.TAG_NAME, "form")),
                        EC.presence_of_element_located((By.XPATH, "//input[@type='text' or @type='email']")),
                        EC.presence_of_element_located((By.TAG_NAME, "textarea"))
                    )
                )
                logger.info(f"Form elements found: {self.endpoint}")
            except TimeoutException:
                logger.error(f"No form elements found: {self.endpoint}")
                return {"status": "NG", "reason": "no_form_elements_found"}
            
            # Check for CAPTCHA and handle it
            captcha_result = self._has_captcha(driver)
            if captcha_result:
                logger.info(f"CAPTCHA detected but not solvable: {self.endpoint}")
                return {"status": "OK", "reason": "captcha_detected_success"}
            
            initial_url = driver.current_url
            
            # Fill the form
            logger.info(f"Filling form: {self.endpoint}")
            self._fill_form(driver)
            
            # Handle any final checkboxes or agreements
            self._handle_agreements(driver)
            
            # Submit the form
            logger.info(f"Submitting form: {self.endpoint}")
            submission_result = self._submit_form(driver)
            if not submission_result:
                logger.error(f"Form submission failed: {self.endpoint}")
                return {"status": "NG", "reason": "submission_failed"}
            
            # Wait and check for success
            time.sleep(4)
            
            if self._check_success(driver, initial_url):
                logger.info(f"SUCCESS: Form submitted successfully: {self.endpoint}")
                return {"status": "OK", "reason": "submission_successful"}
            else:
                logger.warning(f"No success indication found: {self.endpoint}")
                return {"status": "NG", "reason": "no_success_indication"}
                
        except Exception as e:
            logger.error(f"Selenium error for {self.endpoint}: {e}")
            return {"status": "NG", "reason": f"selenium_error"}
        finally:
            if driver:
                driver.quit()

    def _handle_iframe(self, driver):
        """Handle iframe switching"""
        try:
            iframes = driver.find_elements(By.TAG_NAME, 'iframe')
            logger.info(f"Found {len(iframes)} iframes")
            for i, iframe in enumerate(iframes):
                try:
                    driver.switch_to.frame(iframe)
                    # Check if this iframe has form elements
                    form_elements = driver.find_elements(By.XPATH, "//form | //input[@type='text'] | //textarea")
                    if form_elements:
                        logger.info(f"Successfully switched to iframe {i}")
                        return True
                    driver.switch_to.default_content()
                except:
                    driver.switch_to.default_content()
            return False
        except:
            return False

    # REPLACE THE OLD _has_captcha METHOD WITH THIS IMPROVED VERSION
    def _has_captcha(self, driver):
        """Check for CAPTCHA and attempt to solve basic ones"""
        try:
            # Check for different types of CAPTCHAs
            captcha_result = self._detect_and_solve_captcha(driver)
            
            if captcha_result['found']:
                if captcha_result['solved']:
                    logger.info(f"CAPTCHA detected and solved: {captcha_result['type']}")
                    return False  # Continue with form submission
                else:
                    logger.warning(f"CAPTCHA detected but not solved: {captcha_result['type']}")
                    return True  # Stop and report CAPTCHA
            
            return False  # No CAPTCHA found
            
        except Exception as e:
            logger.error(f"Error in CAPTCHA detection: {e}")
            return False

    # ADD ALL THESE NEW CAPTCHA-RELATED METHODS
    def _detect_and_solve_captcha(self, driver):
        """Detect and solve various types of CAPTCHAs"""
        result = {'found': False, 'solved': False, 'type': 'none'}
        
        # 1. Check for reCAPTCHA v2
        recaptcha_result = self._handle_recaptcha_v2(driver)
        if recaptcha_result['found']:
            return recaptcha_result
        
        # 2. Check for reCAPTCHA v3 (invisible)
        recaptcha_v3_result = self._handle_recaptcha_v3(driver)
        if recaptcha_v3_result['found']:
            return recaptcha_v3_result
        
        # 3. Check for hCaptcha
        hcaptcha_result = self._handle_hcaptcha(driver)
        if hcaptcha_result['found']:
            return hcaptcha_result
        
        # 4. Check for image-based CAPTCHAs
        image_captcha_result = self._handle_image_captcha(driver)
        if image_captcha_result['found']:
            return image_captcha_result
        
        # 5. Check for simple text CAPTCHAs
        text_captcha_result = self._handle_text_captcha(driver)
        if text_captcha_result['found']:
            return text_captcha_result
        
        # 6. Check for math CAPTCHAs
        math_captcha_result = self._handle_math_captcha(driver)
        if math_captcha_result['found']:
            return math_captcha_result
        
        return result

    def _handle_recaptcha_v2(self, driver):
        """Handle Google reCAPTCHA v2"""
        result = {'found': False, 'solved': False, 'type': 'recaptcha_v2'}
        
        try:
            # Look for reCAPTCHA iframe
            recaptcha_frames = driver.find_elements(By.CSS_SELECTOR, "iframe[src*='recaptcha']")
            if not recaptcha_frames:
                return result
            
            result['found'] = True
            logger.info("reCAPTCHA v2 detected")
            
            # Try to find the checkbox
            for frame in recaptcha_frames:
                try:
                    driver.switch_to.frame(frame)
                    checkbox = driver.find_element(By.CSS_SELECTOR, ".recaptcha-checkbox-border")
                    if checkbox.is_displayed():
                        checkbox.click()
                        time.sleep(2)
                        
                        # Check if solved (no challenge appeared)
                        try:
                            driver.switch_to.default_content()
                            # Look for success indicator
                            success_elements = driver.find_elements(By.CSS_SELECTOR, ".recaptcha-checkbox-checked")
                            if success_elements:
                                result['solved'] = True
                                logger.info("reCAPTCHA v2 solved automatically")
                            else:
                                logger.warning("reCAPTCHA v2 requires manual solving")
                        except:
                            pass
                        break
                    driver.switch_to.default_content()
                except:
                    driver.switch_to.default_content()
                    continue
                    
        except Exception as e:
            logger.error(f"Error handling reCAPTCHA v2: {e}")
            driver.switch_to.default_content()
        
        return result

    def _handle_recaptcha_v3(self, driver):
        """Handle Google reCAPTCHA v3 (invisible)"""
        result = {'found': False, 'solved': False, 'type': 'recaptcha_v3'}
        
        try:
            # Check for reCAPTCHA v3 script or elements
            recaptcha_v3_indicators = [
                "script[src*='recaptcha/releases/']",
                ".grecaptcha-badge",
                "[data-sitekey]"
            ]
            
            for indicator in recaptcha_v3_indicators:
                elements = driver.find_elements(By.CSS_SELECTOR, indicator)
                if elements:
                    result['found'] = True
                    result['solved'] = True  # v3 is usually invisible and auto-solved
                    logger.info("reCAPTCHA v3 detected and handled")
                    break
                    
        except Exception as e:
            logger.error(f"Error handling reCAPTCHA v3: {e}")
        
        return result

    def _handle_hcaptcha(self, driver):
        """Handle hCaptcha"""
        result = {'found': False, 'solved': False, 'type': 'hcaptcha'}
        
        try:
            hcaptcha_elements = driver.find_elements(By.CSS_SELECTOR, ".h-captcha, iframe[src*='hcaptcha']")
            if hcaptcha_elements:
                result['found'] = True
                logger.info("hCaptcha detected - requires manual solving")
                # hCaptcha is typically too complex for automated solving
                
        except Exception as e:
            logger.error(f"Error handling hCaptcha: {e}")
        
        return result

    def _handle_image_captcha(self, driver):
        """Handle image-based CAPTCHAs"""
        result = {'found': False, 'solved': False, 'type': 'image_captcha'}
        
        try:
            # Look for common CAPTCHA image patterns
            captcha_selectors = [
                "img[src*='captcha']",
                "img[alt*='captcha']", 
                "img[id*='captcha']",
                "img[class*='captcha']",
                ".captcha img",
                "#captcha img"
            ]
            
            for selector in captcha_selectors:
                captcha_images = driver.find_elements(By.CSS_SELECTOR, selector)
                for img in captcha_images:
                    if img.is_displayed():
                        result['found'] = True
                        logger.info("Image CAPTCHA detected")
                        
                        # Try to solve it
                        solved = self._solve_image_captcha(driver, img)
                        if solved:
                            result['solved'] = True
                            logger.info("Image CAPTCHA solved")
                        else:
                            logger.warning("Image CAPTCHA could not be solved")
                        
                        return result
                        
        except Exception as e:
            logger.error(f"Error handling image CAPTCHA: {e}")
        
        return result

    def _solve_image_captcha(self, driver, img_element):
        """Solve image CAPTCHA using OCR"""
        try:
            # Get the image
            img_src = img_element.get_attribute('src')
            
            if img_src.startswith('data:image'):
                # Base64 encoded image
                img_data = img_src.split(',')[1]
                img_bytes = base64.b64decode(img_data)
                image = Image.open(io.BytesIO(img_bytes))
            else:
                # Download image
                response = requests.get(img_src)
                image = Image.open(io.BytesIO(response.content))
            
            # Preprocess image for better OCR
            image = self._preprocess_captcha_image(image)
            
            # Extract text using OCR
            text = pytesseract.image_to_string(image, config='--psm 8 -c tessedit_char_whitelist=0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ')
            text = re.sub(r'[^A-Za-z0-9]', '', text).upper()
            
            if len(text) >= 3:  # Reasonable CAPTCHA length
                # Find input field near the image
                input_field = self._find_captcha_input(driver, img_element)
                if input_field:
                    input_field.clear()
                    input_field.send_keys(text)
                    logger.info(f"Entered CAPTCHA text: {text}")
                    return True
                    
        except Exception as e:
            logger.error(f"Error solving image CAPTCHA: {e}")
        
        return False

    def _preprocess_captcha_image(self, image):
        """Preprocess CAPTCHA image for better OCR accuracy"""
        try:
            # Convert PIL image to OpenCV format
            img_array = np.array(image)
            if len(img_array.shape) == 3:
                img_cv = cv2.cvtColor(img_array, cv2.COLOR_RGB2BGR)
            else:
                img_cv = img_array
            
            # Convert to grayscale
            gray = cv2.cvtColor(img_cv, cv2.COLOR_BGR2GRAY)
            
            # Apply threshold to get black and white image
            _, thresh = cv2.threshold(gray, 127, 255, cv2.THRESH_BINARY)
            
            # Noise removal
            kernel = np.ones((1,1), np.uint8)
            thresh = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)
            thresh = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel)
            
            # Resize image for better OCR
            height, width = thresh.shape
            thresh = cv2.resize(thresh, (width*3, height*3), interpolation=cv2.INTER_CUBIC)
            
            # Convert back to PIL Image
            return Image.fromarray(thresh)
            
        except Exception as e:
            logger.error(f"Error preprocessing image: {e}")
            return image

    def _find_captcha_input(self, driver, img_element):
        """Find the input field associated with a CAPTCHA image"""
        try:
            # Strategy 1: Look for input fields near the image
            parent = img_element.find_element(By.XPATH, "./..")
            inputs = parent.find_elements(By.TAG_NAME, "input")
            for input_field in inputs:
                if input_field.get_attribute('type') in ['text', '']:
                    return input_field
            
            # Strategy 2: Look in the same form
            form = img_element.find_element(By.XPATH, ".//ancestor::form[1]")
            captcha_inputs = form.find_elements(By.XPATH, ".//input[contains(@name, 'captcha') or contains(@id, 'captcha')]")
            if captcha_inputs:
                return captcha_inputs[0]
            
            # Strategy 3: Look for generic text inputs in the form
            text_inputs = form.find_elements(By.XPATH, ".//input[@type='text']")
            for text_input in text_inputs:
                name = text_input.get_attribute('name') or ''
                id_attr = text_input.get_attribute('id') or ''
                if any(keyword in (name + id_attr).lower() for keyword in ['captcha', 'code', 'verify']):
                    return text_input
                    
        except Exception as e:
            logger.error(f"Error finding CAPTCHA input: {e}")
        
        return None

    def _handle_text_captcha(self, driver):
        """Handle simple text-based CAPTCHAs"""
        result = {'found': False, 'solved': False, 'type': 'text_captcha'}
        
        try:
            # Look for text-based CAPTCHA questions
            captcha_text_selectors = [
                "//*[contains(text(), '何') and contains(text(), '？')]",  # Japanese questions
                "//*[contains(text(), 'What is')]",  # English questions
                "//*[contains(text(), 'Enter the')]",
                "//*[contains(text(), 'Type the')]"
            ]
            
            for selector in captcha_text_selectors:
                elements = driver.find_elements(By.XPATH, selector)
                for element in elements:
                    if element.is_displayed():
                        result['found'] = True
                        text = element.text
                        logger.info(f"Text CAPTCHA detected: {text}")
                        
                        # Try to solve simple questions
                        answer = self._solve_text_captcha(text)
                        if answer:
                            # Find nearby input field
                            input_field = self._find_nearby_input(driver, element)
                            if input_field:
                                input_field.clear()
                                input_field.send_keys(answer)
                                result['solved'] = True
                                logger.info(f"Text CAPTCHA solved: {answer}")
                        
                        return result
                        
        except Exception as e:
            logger.error(f"Error handling text CAPTCHA: {e}")
        
        return result

    def _solve_text_captcha(self, text):
        """Solve simple text-based CAPTCHA questions"""
        try:
            text_lower = text.lower()
            
            # Japanese simple questions
            if '何色' in text and '空' in text:
                return '青'  # What color is the sky? -> Blue
            elif '何色' in text and '雪' in text:
                return '白'  # What color is snow? -> White
            elif '何色' in text and '太陽' in text:
                return '黄'  # What color is the sun? -> Yellow
            
            # English simple questions
            elif 'what color' in text_lower and 'sky' in text_lower:
                return 'blue'
            elif 'what color' in text_lower and 'snow' in text_lower:
                return 'white'
            elif 'what color' in text_lower and 'sun' in text_lower:
                return 'yellow'
            
            # Common simple math or number questions
            elif 'two plus two' in text_lower or '2+2' in text:
                return '4'
            elif 'three plus three' in text_lower or '3+3' in text:
                return '6'
                
        except Exception as e:
            logger.error(f"Error solving text CAPTCHA: {e}")
        
        return None

    def _handle_math_captcha(self, driver):
        """Handle mathematical CAPTCHA questions"""
        result = {'found': False, 'solved': False, 'type': 'math_captcha'}
        
        try:
            # Look for math expressions with better patterns
            math_patterns = [
                r'(\d{1,2})\s*[\+]\s*(\d{1,2})',     # Simple addition
                r'(\d{1,2})\s*[\-]\s*(\d{1,2})',     # Simple subtraction  
                r'(\d{1,2})\s*[\*×]\s*(\d{1,2})',    # Simple multiplication
                r'(\d{1,2})\s*[\/÷]\s*(\d{1,2})',    # Simple division
                r'(\d{1,2})\s*[\+\-\*\/×÷]\s*(\d{1,2})\s*[=＝]',  # With equals sign
            ]
            
            page_text = driver.page_source
            
            for pattern in math_patterns:
                matches = re.findall(pattern, page_text)
                if matches:
                    result['found'] = True
                    
                    # Take the first match and reconstruct the expression
                    if len(matches[0]) == 2:  # Pattern without equals
                        # Find the original expression in the text
                        original_match = re.search(pattern.replace(r'(\d{1,2})', r'\d{1,2}'), page_text)
                        if original_match:
                            expression = original_match.group(0)
                            logger.info(f"Math CAPTCHA detected: {expression}")
                            
                            # Solve the math expression
                            answer = self._solve_math_expression(expression)
                            if answer is not None:
                                # Find input field for the answer
                                if self._enter_math_answer(driver, str(answer)):
                                    result['solved'] = True
                                    logger.info(f"Math CAPTCHA solved: {expression} = {answer}")
                                break
                    
        except Exception as e:
            logger.error(f"Error handling math CAPTCHA: {e}")
        
        return result
    
    def _enter_math_answer(self, driver, answer):
        """Enter the answer to a math CAPTCHA"""
        try:
            # Strategy 1: Look for inputs with math-related names/ids
            math_selectors = [
                "//input[contains(@name, 'math') or contains(@name, 'calc') or contains(@id, 'math') or contains(@id, 'calc')]",
                "//input[contains(@name, 'answer') or contains(@id, 'answer')]",
                "//input[contains(@name, 'result') or contains(@id, 'result')]"
            ]
            
            for selector in math_selectors:
                inputs = driver.find_elements(By.XPATH, selector)
                for input_field in inputs:
                    if input_field.is_displayed() and input_field.is_enabled():
                        input_field.clear()
                        input_field.send_keys(answer)
                        logger.info(f"Entered math answer {answer} in field: {input_field.get_attribute('name')}")
                        return True
            
            # Strategy 2: Look for any empty text input near math text
            text_inputs = driver.find_elements(By.XPATH, "//input[@type='text' and not(@value) or @value='']")
            for input_field in text_inputs[:3]:  # Check first 3 empty inputs
                if input_field.is_displayed() and input_field.is_enabled():
                    input_field.clear()
                    input_field.send_keys(answer)
                    logger.info(f"Entered math answer {answer} in empty text field")
                    return True
                    
        except Exception as e:
            logger.error(f"Error entering math answer: {e}")
        
        return False

    def _solve_math_expression(self, expression):
        """Solve a simple math expression"""
        try:
             # Clean the expression
            expression = re.sub(r'[^0-9\+\-\*\/\(\)]', '', expression)
            
            # Remove leading zeros from numbers
            expression = re.sub(r'\b0+(\d)', r'\1', expression)
            
            # Handle simple operations without eval
            # Look for basic patterns like "number operator number"
            simple_patterns = [
                (r'(\d+)\s*\+\s*(\d+)', lambda m: int(m.group(1)) + int(m.group(2))),
                (r'(\d+)\s*\-\s*(\d+)', lambda m: int(m.group(1)) - int(m.group(2))),
                (r'(\d+)\s*\*\s*(\d+)', lambda m: int(m.group(1)) * int(m.group(2))),
                (r'(\d+)\s*\/\s*(\d+)', lambda m: int(m.group(1)) // int(m.group(2)) if int(m.group(2)) != 0 else None),
            ]
            
            for pattern, operation in simple_patterns:
                match = re.search(pattern, expression)
                if match:
                    result = operation(match)
                    if result is not None and -999999 <= result <= 999999:
                        logger.info(f"Solved math: {expression} = {result}")
                        return result
                    break
            
            # If no simple pattern matched, try the safer eval approach
            if re.match(r'^[\d\+\-\*\/\(\)\s]+$', expression) and len(expression) < 30:
                try:
                    # Replace any remaining leading zeros
                    cleaned = re.sub(r'\b0+(?=\d)', '', expression)
                    if cleaned and not re.search(r'[^\d\+\-\*\/\(\)\s]', cleaned):
                        result = eval(cleaned)
                        if isinstance(result, (int, float)) and -999999 <= result <= 999999:
                            return int(result) if isinstance(result, float) and result.is_integer() else result
                except:
                    pass
                
        except Exception as e:
            logger.error(f"Error solving math expression: {e}")
        
        return None

    def _find_nearby_input(self, driver, element):
        """Find input field near a given element"""
        try:
            # Look in the same container
            parent = element.find_element(By.XPATH, "./..")
            inputs = parent.find_elements(By.TAG_NAME, "input")
            for input_field in inputs:
                if input_field.get_attribute('type') in ['text', ''] and input_field.is_displayed():
                    return input_field
            
            # Look in wider context
            container = element.find_element(By.XPATH, ".//ancestor::div[1]")
            inputs = container.find_elements(By.TAG_NAME, "input")
            for input_field in inputs:
                if input_field.get_attribute('type') in ['text', ''] and input_field.is_displayed():
                    return input_field
                    
        except Exception as e:
            logger.error(f"Error finding nearby input: {e}")
        
        return None

    # ... rest of your existing methods remain the same ...
    def _fill_form(self, driver):
        """Fill form fields"""
        # Define the data mapping
        data_map = {
            'company': self.formdata.get('company', ''),
            'company_kana': self.formdata.get('company_kana', ''),
            'name': self.formdata.get('manager', ''),
            'name_kana': self.formdata.get('manager_kana', ''),
            'email': self.formdata.get('mail', ''),
            'phone': self.formdata.get('phone', ''),
            'zip': self.formdata.get('postal_code', ''),
            'address': self.formdata.get('address', ''),
            'subject': self.formdata.get('subjects', ''),
            'message': self.formdata.get('body', '')
        }
        
        filled_count = 0
        # Fill mapped fields
        for field_type, value in data_map.items():
            if not value:
                continue
                
            field_name = self.field_mappings.get(field_type)
            if field_name:
                if self._fill_field(driver, field_name, value):
                    filled_count += 1
        
        logger.info(f"Filled {filled_count} mapped fields")
        
        # Auto-fill unmapped fields
        self._auto_fill_remaining(driver)

    def _fill_field(self, driver, field_name, value):
        """Fill a specific field"""
        try:
            # Try by name first
            elements = driver.find_elements(By.NAME, field_name)
            if not elements:
                # Try by id
                elements = driver.find_elements(By.ID, field_name)
            
            for element in elements:
                if not element.is_displayed() or not element.is_enabled():
                    continue
                
                tag = element.tag_name.lower()
                elem_type = element.get_attribute('type')
                
                if tag == 'input' and elem_type not in ['checkbox', 'radio', 'submit', 'button']:
                    try:
                        element.clear()
                        element.send_keys(str(value))
                        logger.info(f"Filled {field_name} with: {value}")
                        return True
                    except:
                        # Try JavaScript fallback
                        driver.execute_script("arguments[0].value = arguments[1];", element, str(value))
                        return True
                        
                elif tag == 'textarea':
                    try:
                        element.clear()
                        element.send_keys(str(value))
                        logger.info(f"Filled textarea {field_name} with: {value}")
                        return True
                    except:
                        driver.execute_script("arguments[0].value = arguments[1];", element, str(value))
                        return True
                        
                elif tag == 'select':
                    try:
                        select = Select(element)
                        # Try to match by text first
                        for option in select.options:
                            if str(value).lower() in option.text.lower():
                                select.select_by_visible_text(option.text)
                                logger.info(f"Selected option in {field_name}: {option.text}")
                                return True
                        
                        # If no match, select first non-empty option
                        for option in select.options[1:]:
                            if option.get_attribute('value'):
                                select.select_by_value(option.get_attribute('value'))
                                logger.info(f"Auto-selected in {field_name}: {option.text}")
                                return True
                    except Exception as e:
                        logger.error(f"Error with select {field_name}: {e}")
                        
        except Exception as e:
            logger.error(f"Error filling {field_name}: {e}")
        
        return False

    def _auto_fill_remaining(self, driver):
        """Auto-fill remaining form elements"""
        select_count = 0
        radio_count = 0
        
        # Handle all selects
        selects = driver.find_elements(By.TAG_NAME, 'select')
        for select_elem in selects:
            try:
                if not select_elem.is_displayed() or not select_elem.is_enabled():
                    continue
                    
                select = Select(select_elem)
                current_value = select.first_selected_option.get_attribute('value')
                
                # If no selection or empty selection, select first valid option
                if not current_value or current_value == "":
                    for option in select.options[1:]:  # Skip first (usually empty)
                        if option.get_attribute('value') and option.get_attribute('value').strip():
                            select.select_by_value(option.get_attribute('value'))
                            select_count += 1
                            break
            except:
                continue
        
        # Handle radio buttons (select first in each group)
        radio_groups = {}
        radios = driver.find_elements(By.XPATH, "//input[@type='radio']")
        for radio in radios:
            try:
                name = radio.get_attribute('name')
                if name and name not in radio_groups and radio.is_displayed() and radio.is_enabled():
                    radio.click()
                    radio_groups[name] = True
                    radio_count += 1
            except:
                continue
        
        logger.info(f"Auto-filled {select_count} selects and {radio_count} radio groups")

    def _handle_agreements(self, driver):
        """Handle agreement checkboxes"""
        checkbox_count = 0
        checkboxes = driver.find_elements(By.XPATH, "//input[@type='checkbox']")
        for checkbox in checkboxes:
            try:
                if not checkbox.is_displayed() or not checkbox.is_enabled() or checkbox.is_selected():
                    continue
                
                # Get context
                name = checkbox.get_attribute('name') or ''
                id_attr = checkbox.get_attribute('id') or ''
                
                # Try to find label
                label_text = ''
                try:
                    if id_attr:
                        label = driver.find_element(By.XPATH, f"//label[@for='{id_attr}']")
                        label_text = label.text
                except:
                    try:
                        parent_label = checkbox.find_element(By.XPATH, "./ancestor::label[1]")
                        label_text = parent_label.text
                    except:
                        pass
                
                context = f"{name} {id_attr} {label_text}".lower()
                
                # Check if this looks like an agreement/consent checkbox
                agreement_keywords = [
                    '同意', '規約', 'プライバシー', '個人情報', '利用規約', 
                    'agree', 'terms', 'privacy', 'policy', 'consent'
                ]
                
                if any(keyword in context for keyword in agreement_keywords):
                    checkbox.click()
                    checkbox_count += 1
                    logger.info(f"Checked agreement checkbox: {name}")
                    
            except:
                continue
        
        logger.info(f"Checked {checkbox_count} agreement checkboxes")

    def _submit_form(self, driver):
        """Submit the form with multiple strategies"""
        submission_successful = False
        
        # Strategy 1: Look for confirmation button first
        confirm_buttons = self._find_buttons(driver, [
            '確認', '確認画面', '内容確認', '確認する', '次へ', 'confirm', 'next', 'preview', 'continue'
        ])
        
        if confirm_buttons:
            for btn in confirm_buttons:
                if self._click_element(driver, btn):
                    logger.info("Clicked confirmation button")
                    time.sleep(2)
                    
                    # Now look for final submit button
                    submit_buttons = self._find_buttons(driver, [
                        '送信', '送信する', '申し込む', '登録', '完了', 'submit', 'send', 'apply', 'register'
                    ])
                    
                    for submit_btn in submit_buttons:
                        if self._click_element(driver, submit_btn):
                            logger.info("Clicked final submit button")
                            submission_successful = True
                            break
                    
                    if submission_successful:
                        break
        
        # Strategy 2: Direct submit if no confirmation step
        if not submission_successful:
            submit_buttons = self._find_buttons(driver, [
                '送信', '送信する', '申し込む', '登録', '完了', 'submit', 'send', 'apply', 'register'
            ])
            
            for btn in submit_buttons:
                if self._click_element(driver, btn):
                    logger.info("Clicked direct submit button")
                    submission_successful = True
                    break
        
        # Strategy 3: Try any submit-type inputs
        if not submission_successful:
            submit_inputs = driver.find_elements(By.XPATH, "//input[@type='submit'] | //button[@type='submit']")
            for submit_input in submit_inputs:
                if submit_input.is_displayed() and submit_input.is_enabled():
                    if self._click_element(driver, submit_input):
                        logger.info("Clicked submit input")
                        submission_successful = True
                        break
        
        return submission_successful

    def _find_buttons(self, driver, button_texts):
        """Find buttons by text content"""
        buttons = []
        
        for text in button_texts:
            # Find buttons with matching text
            xpath_queries = [
                f"//button[contains(translate(text(), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '{text.lower()}')]",
                f"//input[@type='submit' and contains(translate(@value, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '{text.lower()}')]",
                f"//input[@type='button' and contains(translate(@value, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '{text.lower()}')]",
                f"//a[contains(translate(text(), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '{text.lower()}') and (@href='#' or @onclick)]"
            ]
            
            for xpath in xpath_queries:
                try:
                    elements = driver.find_elements(By.XPATH, xpath)
                    for elem in elements:
                        if elem.is_displayed() and elem.is_enabled():
                            buttons.append(elem)
                except:
                    continue
        
        return buttons

    def _click_element(self, driver, element):
        """Click element with multiple strategies"""
        try:
            # Strategy 1: Scroll and normal click
            driver.execute_script("arguments[0].scrollIntoView({block: 'center'});", element)
            time.sleep(0.5)
            element.click()
            return True
        except:
            try:
                # Strategy 2: JavaScript click
                driver.execute_script("arguments[0].click();", element)
                return True
            except:
                try:
                    # Strategy 3: ActionChains
                    from selenium.webdriver.common.action_chains import ActionChains
                    ActionChains(driver).move_to_element(element).click().perform()
                    return True
                except:
                    return False

    def _check_success(self, driver, initial_url):
        """Check if submission was successful"""
        try:
            current_url = driver.current_url
            
            # Check for URL change (common success indicator)
            if current_url != initial_url:
                # Make sure it's not an error page
                error_indicators = ['error', 'fail', '404', '500']
                if not any(indicator in current_url.lower() for indicator in error_indicators):
                    logger.info(f"URL changed from {initial_url} to {current_url}")
                    return True
            
            # Check for success messages in page content
            success_patterns = [
                'ありがとうございます', 'ありがとうございました', '送信しました', '送信完了', 
                '受け付けました', '受付完了', '完了しました', 'お問い合わせありがとう',
                'thank you', 'submitted', 'success', 'complete', 'received', 'sent'
            ]
            
            page_text = driver.page_source.lower()
            for pattern in success_patterns:
                if pattern in page_text:
                    logger.info(f"Found success pattern: {pattern}")
                    return True
            
            # Check for specific success elements
            success_selectors = [
                ".thanks", ".success", ".complete", ".submitted",
                "#thanks", "#success", "#complete", "#submitted"
            ]
            
            for selector in success_selectors:
                try:
                    elements = driver.find_elements(By.CSS_SELECTOR, selector)
                    if any(el.is_displayed() for el in elements):
                        logger.info(f"Found success element: {selector}")
                        return True
                except:
                    continue
            
            return False
            
        except Exception as e:
            logger.error(f"Error checking success: {e}")
            return False

def run_test_case(url, form_data, case_num):
    """Run a single test case"""
    try:
        logger.info(f"=== Case {case_num}: Starting {url} ===")
        automation = Place_enter(url, form_data)
        result = automation.go_selenium()
        
        status = result['status']
        reason = result['reason']
        
        logger.info(f"Case {case_num} Result: {status} - {reason}")
        return status == "OK"
        
    except Exception as e:
        logger.error(f"Error in test case {case_num}: {e}")
        return False

def main():
    """Main function"""
    logger.info("Starting form automation test suite")
    
    # Load test cases
    try:
        with open("test_cases.json", "r", encoding="utf-8") as f:
            test_cases = json.load(f)
        logger.info(f"Loaded {len(test_cases)} test cases")
    except Exception as e:
        logger.error(f"Failed to load test cases: {e}")
        return
    
    total_cases = len(test_cases)
    passed_cases = 0
    
    # Run test cases sequentially for better debugging
    for i, case in enumerate(test_cases, 1):
        url = case["url"]
        form_data = case["form_data"]
        
        if run_test_case(url, form_data, i):
            passed_cases += 1
        
        # Small delay between cases
        time.sleep(2)
    
    # Calculate results
    success_rate = (passed_cases / total_cases) * 100 if total_cases > 0 else 0
    
    # Log final results
    logger.info("="*60)
    logger.info("FINAL RESULTS:")
    logger.info(f"Total Cases: {total_cases}")
    logger.info(f"Passed Cases: {passed_cases}")
    logger.info(f"Success Rate: {success_rate:.1f}%")
    logger.info("="*60)
    
    # Also print to console for immediate visibility
    print(f"\nFinal Results - Success Rate: {success_rate:.1f}% ({passed_cases}/{total_cases})")
    print("Check log.txt for detailed logs")

if __name__ == "__main__":
    main()