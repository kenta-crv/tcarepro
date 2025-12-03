const logger = require('../config/logger');

class FormSubmitter {
  constructor(browser) {
    this.browser = browser;
    this.testData = {
      email: process.env.TEST_EMAIL || 'mail@ebisu-hotel.tokyo',
      phone: process.env.TEST_PHONE || '+1234567890',
      website: process.env.TEST_WEBSITE || 'https://ri-plus.jp/',
      message: process.env.TEST_MESSAGE || 'This is a test submission from automated form filler.',
      firstname: 'Test',
      lastname: 'User',
      fullname: 'Test User',
      company: 'Ri Plus Co., Ltd.',
      subject: 'General Inquiry'
    };
  }

  /**
   * Fill and submit a contact form
   * @param {string} url - The URL to submit
   * @param {Object} formData - The form data from analyzer
   * @param {Page} existingPage - Optional existing page to reuse
   */
  async submitForm(url, formData, existingPage = null) {
    let page = existingPage;
    const shouldClosePage = !existingPage; // Only close if we created it
    
    try {
      logger.info(`Submitting form at: ${url}`);
      
      // Create new page only if one wasn't provided
      if (!page) {
        page = await this.browser.newPage();
        
        // Set viewport and user agent
        await page.setViewport({ width: 1920, height: 1080 });
        await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      }
      
      await page.goto(url, {
        waitUntil: 'networkidle2',
        timeout: 30000
      });

      // Wait for form to be fully loaded
      await page.waitForTimeout(2000);

      // Fill form fields
      const fillResults = await this.fillFormFields(page, formData);
      
      if (!fillResults.success) {
        return {
          success: false,
          error: 'Failed to fill form fields',
          details: fillResults
        };
      }

      logger.info('Form fields filled successfully', { 
        filledCount: fillResults.filledCount 
      });

      // Check and handle acceptance checkboxes and radio buttons BEFORE submitting
      await this.handleAcceptanceCheckboxes(page);

      // Extra: Ensure specific privacy policy checkbox is checked (common pattern)
      await this.ensurePrivacyCheckboxChecked(page);

      // Wait a bit for any validation
      await page.waitForTimeout(1000);

      // Handle CAPTCHA or reCAPTCHA detection
      const hasCaptcha = await this.detectCaptcha(page);
      if (hasCaptcha) {
        logger.warn('CAPTCHA detected, cannot auto-submit', { url });
        return {
          success: false,
          error: 'CAPTCHA detected',
          hasCaptcha: true,
          fieldsFilledCount: fillResults.filledCount
        };
      }

      // Submit form
      const submitResult = await this.clickSubmitButton(page, formData);
      
      if (!submitResult.success) {
        return {
          success: false,
          error: submitResult.error,
          fieldsFilledCount: fillResults.filledCount
        };
      }

      // Wait for submission response
      await page.waitForTimeout(3000);

      const finalUrl = page.url();
      const pageContent = await page.content();
      
      // Detect success indicators
      const successDetected = this.detectSuccessResponse(pageContent, finalUrl, url);

      logger.info('Form submission completed', { 
        url,
        finalUrl,
        successDetected 
      });

      return {
        success: true,
        submittedAt: new Date().toISOString(),
        originalUrl: url,
        finalUrl: finalUrl,
        urlChanged: finalUrl !== url,
        successDetected: successDetected,
        fieldsFilledCount: fillResults.filledCount
      };

    } catch (error) {
      logger.error('Error submitting form:', { 
        url, 
        error: error.message,
        stack: error.stack 
      });
      return {
        success: false,
        error: error.message
      };
    } finally {
      // Only close page if we created it (not passed in)
      if (page && shouldClosePage) {
        await page.close().catch(() => {});
      }
    }
  }

  /**
   * Handle acceptance/agreement checkboxes and radio buttons
   */
  async handleAcceptanceCheckboxes(page) {
    try {
      const results = await page.evaluate(() => {
        let checkboxesChecked = 0;
        let radioButtonsSelected = 0;
        const checkboxDetails = [];
        
        // Find ALL checkboxes on the page
        const checkboxes = document.querySelectorAll('input[type="checkbox"]');
        
        console.log(`Found ${checkboxes.length} checkbox(es) on the page`);
        
        checkboxes.forEach((checkbox, index) => {
          const checkboxInfo = {
            index: index,
            id: checkbox.id,
            name: checkbox.name,
            checked: checkbox.checked,
            disabled: checkbox.disabled,
            visible: checkbox.offsetParent !== null
          };
          
          checkboxDetails.push(checkboxInfo);
          console.log(`Checkbox ${index}:`, checkboxInfo);
          
          if (!checkbox.checked && !checkbox.disabled) {
            // Method 1: Set checked property
            checkbox.checked = true;
            
            // Method 2: Trigger click event
            checkbox.click();
            
            // Method 3: Dispatch multiple events
            checkbox.dispatchEvent(new Event('change', { bubbles: true }));
            checkbox.dispatchEvent(new Event('input', { bubbles: true }));
            checkbox.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
            
            checkboxesChecked++;
            console.log(`Checked checkbox: ${checkbox.name || checkbox.id}`);
          }
        });
        
        // Find ALL radio buttons on the page
        const radioButtons = document.querySelectorAll('input[type="radio"]');
        const radioGroups = {};
        
        console.log(`Found ${radioButtons.length} radio button(s) on the page`);
        
        // Group radio buttons by name
        radioButtons.forEach(radio => {
          const name = radio.name || 'unnamed';
          if (!radioGroups[name]) {
            radioGroups[name] = [];
          }
          radioGroups[name].push(radio);
        });
        
        // Select first available radio button in each group
        Object.keys(radioGroups).forEach(groupName => {
          const group = radioGroups[groupName];
          
          // Check if any radio in this group is already selected
          const hasSelection = group.some(radio => radio.checked);
          
          console.log(`Radio group "${groupName}": ${group.length} buttons, hasSelection: ${hasSelection}`);
          
          // If no selection, select the first non-disabled radio button
          if (!hasSelection) {
            const firstAvailable = group.find(radio => !radio.disabled);
            if (firstAvailable) {
              firstAvailable.checked = true;
              firstAvailable.click();
              
              // Dispatch events to ensure form validation updates
              firstAvailable.dispatchEvent(new Event('change', { bubbles: true }));
              firstAvailable.dispatchEvent(new Event('input', { bubbles: true }));
              firstAvailable.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
              
              radioButtonsSelected++;
              console.log(`Selected radio button: ${firstAvailable.name} = ${firstAvailable.value}`);
            }
          }
        });
        
        return { 
          checkboxesChecked, 
          radioButtonsSelected,
          checkboxDetails,
          totalCheckboxes: checkboxes.length,
          totalRadioButtons: radioButtons.length
        };
      });

      logger.info('Checkbox/Radio handling results:', {
        checkboxesChecked: results.checkboxesChecked,
        radioButtonsSelected: results.radioButtonsSelected,
        totalCheckboxes: results.totalCheckboxes,
        totalRadioButtons: results.totalRadioButtons,
        checkboxDetails: results.checkboxDetails
      });

      if (results.checkboxesChecked > 0 || results.radioButtonsSelected > 0) {
        logger.info(`Checked ${results.checkboxesChecked} checkbox(es) and selected ${results.radioButtonsSelected} radio button group(s)`);
        // Wait a moment for form validation to process
        await page.waitForTimeout(500);
      } else {
        logger.warn('No checkboxes or radio buttons were selected. Check the details above.');
      }

      return results.checkboxesChecked + results.radioButtonsSelected;
    } catch (error) {
      logger.warn('Error handling checkboxes and radio buttons:', { error: error.message });
      return 0;
    }
  }

  /**
   * Ensure privacy/agreement checkboxes are checked (additional safeguard)
   */
  async ensurePrivacyCheckboxChecked(page) {
    try {
      const checked = await page.evaluate(() => {
        // Common patterns for privacy/agreement checkboxes
        const privacyKeywords = [
          'privacy', 'プライバシー', 'agree', '同意', 'terms', '規約',
          'policy', 'ポリシー', 'accept', '承諾', 'consent', '了承'
        ];
        
        let checkedCount = 0;
        const checkboxes = document.querySelectorAll('input[type="checkbox"]');
        
        checkboxes.forEach(checkbox => {
          const name = (checkbox.name || '').toLowerCase();
          const id = (checkbox.id || '').toLowerCase();
          const label = checkbox.labels && checkbox.labels[0] ? 
            (checkbox.labels[0].textContent || '').toLowerCase() : '';
          
          const searchText = name + ' ' + id + ' ' + label;
          
          // Check if this looks like a privacy/agreement checkbox
          const isPrivacyCheckbox = privacyKeywords.some(keyword => 
            searchText.includes(keyword.toLowerCase())
          );
          
          if (isPrivacyCheckbox && !checkbox.checked && !checkbox.disabled) {
            console.log(`Found privacy checkbox: ${checkbox.name || checkbox.id}`);
            checkbox.checked = true;
            checkbox.click();
            checkbox.dispatchEvent(new Event('change', { bubbles: true }));
            checkbox.dispatchEvent(new Event('input', { bubbles: true }));
            checkedCount++;
          }
        });
        
        return checkedCount;
      });
      
      if (checked > 0) {
        logger.info(`Additionally ensured ${checked} privacy checkbox(es) are checked`);
        await page.waitForTimeout(300);
      }
      
      return checked;
    } catch (error) {
      logger.warn('Error in ensurePrivacyCheckboxChecked:', { error: error.message });
      return 0;
    }
  }

  /**
   * Fill all form fields
   */
  async fillFormFields(page, formData) {
    try {
      let filledCount = 0;
      const inputs = formData.inputs;

      for (const input of inputs) {
        try {
          // Skip checkboxes and radio buttons - they're handled by handleAcceptanceCheckboxes
          if (input.type === 'checkbox' || input.type === 'radio') {
            logger.debug(`Skipping ${input.type} field: ${input.name || input.id} (handled separately)`);
            continue;
          }

          const value = this.getValueForField(input);
          
          if (!value) {
            logger.debug(`Skipping field ${input.name || input.id} - no appropriate value`);
            continue;
          }

          // Try multiple strategies to fill the field
          let filled = false;

          // Strategy 1: Fill by ID
          if (input.id) {
            filled = await this.fillFieldById(page, input.id, value);
          }

          // Strategy 2: Fill by name
          if (!filled && input.name) {
            filled = await this.fillFieldByName(page, input.name, value);
          }

          // Strategy 3: Fill by selector
          if (!filled) {
            const selector = this.buildSelector(input);
            filled = await this.fillFieldBySelector(page, selector, value);
          }

          if (filled) {
            filledCount++;
            logger.debug(`Filled field: ${input.name || input.id} = "${value}"`);
          } else {
            logger.warn(`Could not fill field: ${input.name || input.id}`);
          }

        } catch (fieldError) {
          logger.warn(`Error filling field ${input.name || input.id}:`, { 
            error: fieldError.message 
          });
        }
      }

      return {
        success: filledCount > 0,
        filledCount: filledCount,
        totalFields: inputs.length
      };

    } catch (error) {
      logger.error('Error in fillFormFields:', { error: error.message });
      return {
        success: false,
        filledCount: 0,
        error: error.message
      };
    }
  }

  /**
   * Get appropriate value for a field
   */
  getValueForField(input) {
    const fieldType = input.fieldType || 'text';
    const fieldName = (input.name || input.id || '').toLowerCase();
    
    // Map common field names to test data
    if (fieldName.includes('email')) return this.testData.email;
    if (fieldName.includes('phone') || fieldName.includes('telephone')) return this.testData.phone;
    if (fieldName.includes('website') || fieldName.includes('url')) return this.testData.website;
    if (fieldName.includes('first') || fieldName.includes('firstname')) return this.testData.firstname;
    if (fieldName.includes('last') || fieldName.includes('lastname')) return this.testData.lastname;
    if (fieldName.includes('name') && fieldName.includes('full')) return this.testData.fullname;
    if (fieldName.includes('name')) return this.testData.fullname;
    if (fieldName.includes('company') || fieldName.includes('organisation')  || fieldName.includes('organization')) return this.testData.company;
    if (fieldName.includes('subject') || fieldName.includes('title')) return this.testData.subject;
    
    // Fallback based on fieldType
    return this.testData[fieldType] || this.testData.message;
  }

  /**
   * Fill field by ID
   */
  async fillFieldById(page, id, value) {
    try {
      const element = await page.$(`#${CSS.escape(id)}`);
      if (!element) return false;

      await element.click();
      await element.evaluate(el => el.value = '');
      await element.type(value, { delay: 50 });
      
      // Trigger change events
      await element.evaluate(el => {
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
      });

      return true;
    } catch (error) {
      return false;
    }
  }

  /**
   * Fill field by name
   */
  async fillFieldByName(page, name, value) {
    try {
      const element = await page.$(`[name="${name}"]`);
      if (!element) return false;

      await element.click();
      await element.evaluate(el => el.value = '');
      await element.type(value, { delay: 50 });
      
      await element.evaluate(el => {
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
      });

      return true;
    } catch (error) {
      return false;
    }
  }

  /**
   * Fill field by selector
   */
  async fillFieldBySelector(page, selector, value) {
    try {
      const element = await page.$(selector);
      if (!element) return false;

      await element.click();
      await element.evaluate(el => el.value = '');
      await element.type(value, { delay: 50 });
      
      await element.evaluate(el => {
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
      });

      return true;
    } catch (error) {
      return false;
    }
  }

  /**
   * Build CSS selector for input
   */
  buildSelector(input) {
    if (input.tagName === 'textarea') {
      return 'textarea';
    }
    
    if (input.type) {
      return `input[type="${input.type}"]`;
    }
    
    return 'input';
  }

  /**
   * Detect if page has CAPTCHA
   */
  async detectCaptcha(page) {
    try {
      const hasCaptcha = await page.evaluate(() => {
        // Check for common CAPTCHA elements
        const recaptcha = document.querySelector('.g-recaptcha, [data-sitekey], .recaptcha');
        const hcaptcha = document.querySelector('.h-captcha');
        const turnstile = document.querySelector('.cf-turnstile');
        const cloudflare = document.querySelector('iframe[src*="challenges.cloudflare"]');
        
        return !!(recaptcha || hcaptcha || turnstile || cloudflare);
      });

      return hasCaptcha;
    } catch (error) {
      return false;
    }
  }

 // Enhanced clickSubmitButton method with better Japanese support
async clickSubmitButton(page, formData) {
  try {
    const submitButtons = formData.submitButtons;
    
    if (!submitButtons || submitButtons.length === 0) {
      logger.warn('No submit button found in form data');
      return { success: false, error: 'No submit button found' };
    }

    // Check if submit button is still disabled
    const isDisabled = await page.evaluate(() => {
      const submitBtn = document.querySelector('input[type="submit"], button[type="submit"]');
      return submitBtn ? submitBtn.disabled : false;
    });

    if (isDisabled) {
      logger.warn('Submit button is still disabled - may need additional validation');
    }

    // Try to click the submit button with expanded keyword support
    const clicked = await page.evaluate((btnInfo) => {
      // Extended multi-language submit button keywords
      const submitKeywords = [
        // English
        'submit', 'send', 'contact', 'post', 'ok', 'confirm', 'go',
        // Japanese (EXPANDED)
        '送信', '送る', 'submit', '確認', '確認画面', '実行', '次へ', 'を続ける',
        // Spanish
        'enviar', 'envio',
        // French
        'envoyer', 'soumettre',
        // German
        'senden', 'absenden', 'abschicken',
        // Italian
        'inviare', 'spedire',
        // Portuguese
        'enviar', 'submeter',
        // Arabic
        'إرسال', 'أرسل',
        // Korean
        '보내기', '제출', '전송',
        // Chinese
        '发送', '提交', '送出',
        // Dutch
        'verzenden', 'versturen',
        // Swedish
        'skicka', 'skapa',
        // Polish
        'wyślij', 'prześlij'
      ];

      // Strategy 1: Try by ID first
      if (btnInfo.id) {
        const btn = document.getElementById(btnInfo.id);
        if (btn && !btn.disabled) {
          console.log(`Clicking button by ID: ${btnInfo.id}`);
          btn.click();
          return true;
        }
      }

      // Strategy 2: Try input[type="submit"] with enhanced matching
      const submitInputs = document.querySelectorAll('input[type="submit"]');
      for (const btn of submitInputs) {
        if (btn.disabled) continue;
        
        const value = (btn.value || '').trim();
        const searchText = value.toLowerCase();
        
        // Log the button value for debugging
        console.log(`Found submit input with value: "${value}"`);
        
        // Check if button text matches any submit keyword
        const isSubmitButton = submitKeywords.some(keyword => {
          // Case-insensitive for Latin characters
          if (searchText.includes(keyword.toLowerCase())) {
            return true;
          }
          // Exact match for Japanese/CJK characters (case-insensitive not applicable)
          if (value.includes(keyword)) {
            return true;
          }
          return false;
        });
        
        if (isSubmitButton) {
          console.log(`Clicking submit input with value: "${value}"`);
          btn.click();
          return true;
        }
      }

      // Strategy 3: Try button[type="submit"]
      const submitButtons = document.querySelectorAll('button[type="submit"]');
      for (const btn of submitButtons) {
        if (btn.disabled) continue;
        
        const text = (btn.textContent || '').trim();
        const searchText = text.toLowerCase();
        
        console.log(`Found submit button with text: "${text}"`);
        
        const isSubmitButton = submitKeywords.some(keyword => {
          if (searchText.includes(keyword.toLowerCase())) {
            return true;
          }
          if (text.includes(keyword)) {
            return true;
          }
          return false;
        });
        
        if (isSubmitButton) {
          console.log(`Clicking submit button with text: "${text}"`);
          btn.click();
          return true;
        }
      }

      // Strategy 4: Fallback - click ANY input[type="submit"] (last resort)
      if (submitInputs.length > 0) {
        const btn = Array.from(submitInputs).find(b => !b.disabled);
        if (btn) {
          console.log(`Fallback: Clicking first available submit input`);
          btn.click();
          return true;
        }
      }

      // Strategy 5: Try any button (fallback)
      const allButtons = document.querySelectorAll('button, input[type="button"]');
      for (const btn of allButtons) {
        if (btn.disabled) continue;
        
        const text = (btn.textContent || btn.value || '').trim();
        const isSubmitButton = submitKeywords.some(keyword => 
          text.includes(keyword)
        );
        
        if (isSubmitButton) {
          console.log(`Clicking any button with text: "${text}"`);
          btn.click();
          return true;
        }
      }

      console.log('No suitable button found to click');
      return false;
    }, submitButtons[0]);

    if (clicked) {
      logger.info('Submit button clicked successfully');
      return { success: true };
    } else {
      logger.warn('Could not click submit button - check console logs above');
      return { success: false, error: 'Could not click submit button' };
    }

  } catch (error) {
    logger.error('Error clicking submit button:', { error: error.message });
    return { success: false, error: error.message };
  }
}

  /**
   * Detect success response with multi-language support
   */
  detectSuccessResponse(pageContent, finalUrl, originalUrl) {
    const content = pageContent.toLowerCase();
    
    // Multi-language success indicators
    const successKeywords = [
      // English
      'thank you', 'thanks for', 'message sent', 'successfully submitted',
      'received your', 'we\'ll get back', 'we will get back', 'contact you soon',
      'submission successful', 'form submitted', 'success', 'confirmed',
      // Hebrew
      'תודה', 'תודה רבה', 'הודעה נשלחה', 'נשלח בהצלחה',
      // Japanese
      'ありがとう', 'ご送信', '送信完了', '送信されました', '完了',
      // Spanish
      'gracias', 'enviado', 'enviada', 'envío exitoso', 'confirmación',
      // French
      'merci', 'envoyé', 'succès', 'confirmation',
      // German
      'danke', 'gesendet', 'erfolgreich', 'bestätigung',
      // Portuguese
      'obrigado', 'enviado', 'sucesso', 'confirmação',
      // Polish
      'dziękuję', 'wysłane', 'sukces'
    ];

    const hasSuccessKeyword = successKeywords.some(keyword => content.includes(keyword));
    
    // Check if URL changed (often indicates successful submission)
    const urlChanged = finalUrl !== originalUrl;
    
    // Check for thank you page or success page indicators
    const isThankYouPage = finalUrl.includes('thank') || 
                          finalUrl.includes('success') || 
                          finalUrl.includes('confirmation') ||
                          finalUrl.includes('thanks') ||
                          finalUrl.includes('submitted');
    
    return hasSuccessKeyword || isThankYouPage || urlChanged;
  }
}

module.exports = FormSubmitter;