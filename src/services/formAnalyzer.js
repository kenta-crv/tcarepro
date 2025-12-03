const logger = require('../config/logger');

class FormAnalyzer {
  constructor(browser) {
    this.browser = browser;
  }

  /**
   * Validate if URL is valid and can be navigated to
   */
  isValidUrl(url) {
    if (!url || typeof url !== 'string') {
      return false;
    }
    
    // Reject javascript: URLs and other invalid protocols
    if (url.startsWith('javascript:') || url.startsWith('data:') || url.startsWith('about:')) {
      return false;
    }
    
    // Check if it's a relative URL - convert to placeholder for validation
    if (url.startsWith('/') || url.startsWith('#')) {
      return true; // Valid relative URL
    }
    
    // Check if it's an absolute URL
    try {
      new URL(url);
      return true;
    } catch (e) {
      return false;
    }
  }

  /**
   * Extract and analyze all input fields from a page
   * @param {string} url - The URL to analyze
   * @param {string} baseUrl - Base URL for resolving relative URLs
   * @param {Page} existingPage - Optional existing page to reuse
   */
  async analyzeForm(url, baseUrl = null, existingPage = null) {
    // Validate URL
    if (!this.isValidUrl(url)) {
      logger.error('Invalid URL provided to analyzeForm', { url });
      return {
        allForms: [],
        contactForm: null,
        totalForms: 0,
        error: `Invalid URL: ${url}`
      };
    }

    let page = existingPage;
    const shouldClosePage = !existingPage;
    
    try {
      logger.info(`Analyzing form at: ${url}`);
      
      if (!page) {
        page = await this.browser.newPage();
        await page.setViewport({ width: 1920, height: 1080 });
        await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      }
      
      // Resolve relative URLs if baseUrl is provided
      let finalUrl = url;
      if (baseUrl && (url.startsWith('/') || url.startsWith('#'))) {
        try {
          finalUrl = new URL(url, baseUrl).toString();
          logger.info(`Resolved relative URL to: ${finalUrl}`);
        } catch (e) {
          logger.warn(`Could not resolve relative URL: ${url}`, { baseUrl });
          finalUrl = url;
        }
      }

      await page.goto(finalUrl, {
        waitUntil: 'networkidle2',
        timeout: 30000
      });

      // Wait for forms to load
      try {
        await page.waitForSelector('form', { timeout: 5000 });
      } catch (e) {
        logger.warn('No forms found in DOM', { url: finalUrl });
      }

      // Extended wait for dynamic content
      await page.waitForTimeout(3000);

      // Extract form information
      const formData = await page.evaluate(() => {
        const forms = [];
        const formElements = document.querySelectorAll('form');
        
        formElements.forEach((form, formIndex) => {
          const inputs = [];
          const elements = form.querySelectorAll('input, textarea, select');
          
          elements.forEach((el) => {
            // Skip hidden inputs and buttons
            if (el.type === 'hidden' || el.type === 'button' || el.type === 'submit') {
              return;
            }
            
            // Enhanced visibility check
            const rect = el.getBoundingClientRect();
            const computedStyle = window.getComputedStyle(el);
            
            let isVisible = rect.width > 0 && rect.height > 0;
            
            if (isVisible) {
              isVisible = computedStyle.visibility !== 'hidden' && 
                         computedStyle.display !== 'none' &&
                         computedStyle.opacity !== '0';
            }
            
            // Check parent visibility
            if (isVisible) {
              let parent = el.parentElement;
              let depth = 0;
              while (parent && parent !== form && depth < 10) {
                const parentStyle = window.getComputedStyle(parent);
                if (parentStyle.display === 'none' || parentStyle.visibility === 'hidden') {
                  isVisible = false;
                  break;
                }
                parent = parent.parentElement;
                depth++;
              }
            }
            
            if (!isVisible) return;
            
            // Get label text
            let label = '';
            if (el.id) {
              const labelEl = document.querySelector(`label[for="${el.id}"]`);
              if (labelEl) label = labelEl.textContent.trim();
            }
            if (!label) {
              const parentLabel = el.closest('label');
              if (parentLabel) label = parentLabel.textContent.trim();
            }
            
            inputs.push({
              tagName: el.tagName.toLowerCase(),
              type: el.type || 'text',
              name: el.name || '',
              id: el.id || '',
              placeholder: el.placeholder || '',
              label: label,
              required: el.required || false,
              pattern: el.pattern || '',
              minLength: el.minLength || null,
              maxLength: el.maxLength || null,
              className: el.className || '',
              autocomplete: el.autocomplete || ''
            });
          });
          
          // Get submit button info
          const submitButtons = [];
          const buttons = form.querySelectorAll('button[type="submit"], input[type="submit"], button:not([type])');
          buttons.forEach(btn => {
            const rect = btn.getBoundingClientRect();
            const computedStyle = window.getComputedStyle(btn);
            const isVisible = rect.width > 0 && rect.height > 0 && 
                            computedStyle.display !== 'none' &&
                            computedStyle.visibility !== 'hidden';
            
            if (isVisible) {
              submitButtons.push({
                type: btn.tagName.toLowerCase(),
                text: btn.textContent.trim() || btn.value || '',
                id: btn.id || '',
                className: btn.className || ''
              });
            }
          });
          
          forms.push({
            index: formIndex,
            action: form.action || '',
            method: form.method || 'post',
            id: form.id || '',
            className: form.className || '',
            inputs: inputs,
            submitButtons: submitButtons
          });
        });
        
        return forms;
      });

      logger.info(`Extracted ${formData.length} forms`, {
        forms: formData.map(f => ({
          index: f.index,
          inputCount: f.inputs.length,
          buttonCount: f.submitButtons.length
        }))
      });

      // Analyze and categorize forms
      const analyzedForms = formData.map(form => this.categorizeForm(form));
      
      // Log all forms with their details
      analyzedForms.forEach((form, idx) => {
        logger.info(`Form ${idx}:`, {
          index: form.index,
          score: form.score,
          inputCount: form.inputs.length,
          fieldTypes: form.inputs.map(i => i.fieldType),
          submitButtons: form.submitButtons.length,
          submitButtonTexts: form.submitButtons.map(b => b.text)
        });
      });

      // Find the best form
      const contactForm = this.findBestContactForm(analyzedForms);
      
      if (contactForm) {
        logger.info(`Found contact form with ${contactForm.inputs.length} fields`, {
          url: finalUrl,
          formIndex: contactForm.index,
          inputCount: contactForm.inputs.length,
          score: contactForm.score
        });
      } else {
        logger.warn('No suitable contact form found', { 
          url: finalUrl,
          totalForms: formData.length,
          formScores: analyzedForms.map(f => ({
            index: f.index,
            score: f.score,
            inputs: f.inputs.length
          }))
        });
      }

      return {
        allForms: analyzedForms,
        contactForm: contactForm,
        totalForms: formData.length
      };

    } catch (error) {
      logger.error('Error analyzing form:', { 
        url, 
        error: error.message,
        stack: error.stack 
      });
      return {
        allForms: [],
        contactForm: null,
        totalForms: 0,
        error: error.message
      };
    } finally {
      if (page && shouldClosePage) {
        await page.close().catch(() => {});
      }
    }
  }

  /**
   * Categorize form fields
   */
  categorizeForm(form) {
    const categorizedInputs = form.inputs.map(input => {
      const fieldType = this.detectFieldType(input);
      return { ...input, fieldType };
    });

    return {
      ...form,
      inputs: categorizedInputs,
      score: this.calculateFormScore(categorizedInputs, form.submitButtons)
    };
  }

  /**
   * Detect the semantic type of a field
   */
  detectFieldType(input) {
    const searchStr = `${input.name} ${input.id} ${input.placeholder} ${input.label} ${input.className} ${input.autocomplete}`.toLowerCase();
    
    // Email field
    if (input.type === 'email' || searchStr.match(/email|e-mail|mail|メール|メールアドレス/)) {
      return 'email';
    }
    
    // Phone field
    if (input.type === 'tel' || searchStr.match(/phone|tel|mobile|contact.*number|電話|携帯|電話番号/)) {
      return 'phone';
    }
    
    // Name fields (full name)
    if (searchStr.match(/^name$|full.*name|your.*name|contact.*name|氏名|名前|fullname/)) {
      return 'fullname';
    }
    
    // First name
    if (searchStr.match(/first.*name|fname|given.*name|first_name|first-name|first_kana/)) {
      return 'firstname';
    }
    
    // Last name
    if (searchStr.match(/last.*name|lname|surname|family.*name|last_name|last-name|last_kana/)) {
      return 'lastname';
    }
    
    // Company/Organization
    if (searchStr.match(/company|organization|organisation|business|会社|企業|会社名|corporation/)) {
      return 'company';
    }
    
    // Department
    if (searchStr.match(/department|dept|部署|department_name|部門|部署名/)) {
      return 'department';
    }
    
    // Job title
    if (searchStr.match(/job.*title|title|position|role|職|役職|job_title|職種|役職名/)) {
      return 'jobtitle';
    }
    
    // Website/URL
    if (input.type === 'url' || searchStr.match(/website|url|site|ウェブサイト|web_site|homepage|url|会社url/)) {
      return 'website';
    }
    
    // Message/Comment (textarea or message-like fields)
    if (input.tagName === 'textarea' || searchStr.match(/message|comment|inquiry|enquiry|details|description|question|お問い合わせ|内容|詳細|メッセージ|description|comments|body|content/)) {
      return 'message';
    }
    
    // Subject
    if (searchStr.match(/subject|topic|regarding|件名|タイトル|subject_line/)) {
      return 'subject';
    }
    
    // Generic text
    return 'text';
  }

  /**
   * Calculate form relevance score
   */
  calculateFormScore(inputs, submitButtons) {
    let score = 0;
    
    // Check for essential contact form fields
    const hasEmail = inputs.some(i => i.fieldType === 'email');
    const hasMessage = inputs.some(i => i.fieldType === 'message');
    const hasName = inputs.some(i => ['fullname', 'firstname', 'lastname'].includes(i.fieldType));
    const hasCompany = inputs.some(i => i.fieldType === 'company');
    
    if (hasEmail) {
      score += 40;
    }
    
    if (hasMessage) {
      score += 35;
    }
    
    if (hasName) {
      score += 20;
    }
    
    if (hasCompany) {
      score += 10;
    }
    
    // Reasonable number of fields (2-25 is typical for contact forms)
    if (inputs.length >= 2 && inputs.length <= 25) {
      score += 15;
    } else if (inputs.length > 25) {
      score -= 15;
    } else if (inputs.length < 2) {
      score -= 20;
    }
    
    // Has submit button
    if (submitButtons.length > 0) {
      score += 15;
      
      // Check submit button text
      const btnText = submitButtons[0].text.toLowerCase();
      if (btnText.match(/submit|send|contact|inquire|enquire|送信|送る|申込|お問い合わせ|確認|次へ/)) {
        score += 10;
      }
    }
    
    return score;
  }

  /**
   * Find the most likely contact form
   */
  findBestContactForm(forms) {
    if (forms.length === 0) {
      logger.warn('No forms to evaluate');
      return null;
    }
    
    // Sort by score
    forms.sort((a, b) => b.score - a.score);
    
    const topForm = forms[0];
    logger.info(`Top form has score: ${topForm.score}`, {
      formIndex: topForm.index,
      inputCount: topForm.inputs.length,
      hasEmail: topForm.inputs.some(i => i.fieldType === 'email'),
      hasMessage: topForm.inputs.some(i => i.fieldType === 'message'),
      hasName: topForm.inputs.some(i => ['fullname', 'firstname', 'lastname'].includes(i.fieldType)),
      submitButtons: topForm.submitButtons.length
    });
    
    // Check if top form meets threshold
    if (topForm.score >= 30) {
      logger.info(`Form meets threshold (score: ${topForm.score})`);
      return topForm;
    }
    
    // Fallback: If form has email + message + submit button, accept it anyway
    const fallback = forms.find(form => {
      const hasEmail = form.inputs.some(i => i.fieldType === 'email');
      const hasMessage = form.inputs.some(i => i.fieldType === 'message');
      const hasSubmit = form.submitButtons.length > 0;
      return hasEmail && hasMessage && hasSubmit;
    });
    
    if (fallback) {
      logger.info('Using fallback form: has email + message + submit button', {
        score: fallback.score,
        formIndex: fallback.index
      });
      return fallback;
    }
    
    logger.warn(`No form meets criteria. Top form score: ${topForm.score}`);
    return null;
  }
}

module.exports = FormAnalyzer;