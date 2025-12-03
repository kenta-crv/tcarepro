const logger = require('../config/logger');

class ContactPageFinder {
  constructor(browser) {
    this.browser = browser;
    this.commonPaths = [
      '/contact/',
      '/contact-us/',
      '/contactus/',
      '/get-in-touch/',
      '/contact',
      '/reach-us/',
      '/inquiry/',
      '/support/',
      '/contact-form/',
      '/connect/',
      '/touch/',
      '/enquiry/',
      '/enquiries/'
    ];

    // Multi-language contact keywords
    this.contactKeywords = {
      english: ['contact', 'reach', 'touch', 'inquiry', 'inquire', 'enquiry', 'support', 'connect', 'message', 'get in touch'],
      hebrew: ['צור קשר', 'יצור קשר', 'צרו קשר', 'קשר', 'פנייה', 'תקשורת'],
      japanese: ['お問い合わせ', '問い合わせ', 'お問合せ', 'コンタクト', '連絡', 'ご連絡', 'サポート', 'お支持'],
      spanish: ['contacto', 'contactenos', 'ponte en contacto', 'comunicarse', 'soporte'],
      french: ['contact', 'nous contacter', 'contacter', 'support'],
      german: ['kontakt', 'kontaktieren', 'kontakt aufnehmen', 'support'],
      italian: ['contatti', 'contattaci', 'contatto', 'supporto'],
      portuguese: ['contato', 'contatenos', 'suporte', 'entrar em contato'],
      arabic: ['اتصل', 'تواصل', 'التواصل', 'دعم'],
      korean: ['문의', '연락', '지원', '문의하기', '문의 사항'],
      chinese: ['联系', '联系我们', '接触', '支持', '留言', '咨询']
    };
  }

  /**
   * Check if a URL is valid for navigation
   */
  isValidNavigableUrl(url) {
    if (!url || typeof url !== 'string') {
      return false;
    }
    
    // Reject javascript: URLs and other invalid protocols
    if (url.startsWith('javascript:') || 
        url.startsWith('data:') || 
        url.startsWith('about:') ||
        url.trim() === '#' ||
        url.includes('void')) {
      return false;
    }
    
    return true;
  }

  /**
   * Check if homepage has a contact form
   */
  async hasContactFormOnPage(page) {
    try {
      const formCount = await page.evaluate(() => {
        return document.querySelectorAll('form').length;
      });
      
      return formCount > 0;
    } catch (error) {
      logger.debug('Error checking for form on page:', { error: error.message });
      return false;
    }
  }

  /**
   * Find contact page by trying common URL patterns
   */
  async findByDirectUrl(homepage, existingPage) {
    try {
      const baseUrl = new URL(homepage);
      logger.info(`Trying direct URL patterns for: ${baseUrl.origin}`);

      for (const path of this.commonPaths) {
        const testUrl = `${baseUrl.origin}${path}`;
        
        try {
          const response = await existingPage.goto(testUrl, { 
            timeout: 15000,
            waitUntil: 'domcontentloaded'
          });
          
          const isValid = response && response.status() === 200;
          
          if (isValid) {
            // Verify this page has a form
            const hasForm = await this.hasContactFormOnPage(existingPage);
            if (hasForm) {
              logger.info(`Contact page found via direct URL: ${testUrl}`);
              return testUrl;
            }
          }
        } catch (error) {
          logger.debug(`Direct URL failed: ${testUrl}`, { error: error.message });
        }
      }

      return null;
    } catch (error) {
      logger.error('Error in findByDirectUrl:', { error: error.message });
      return null;
    }
  }

  /**
   * Find contact page by analyzing homepage links (including nested span text)
   */
  async findByHomepageLinks(homepage, existingPage) {
    try {
      logger.info(`Analyzing homepage links: ${homepage}`);
      
      await existingPage.goto(homepage, {
        waitUntil: 'networkidle2',
        timeout: 30000
      });

      // Extract all links with comprehensive text extraction
      const links = await existingPage.evaluate(() => {
        const result = [];
        const anchors = document.querySelectorAll('a[href]');
        
        for (const anchor of anchors) {
          // Get text from anchor and all child elements
          const directText = (anchor.textContent || '').trim().toLowerCase();
          
          // Also extract text from span elements within the anchor
          const spans = anchor.querySelectorAll('span');
          const spanTexts = Array.from(spans)
            .map(span => (span.textContent || '').trim().toLowerCase())
            .filter(text => text.length > 0)
            .join(' ');
          
          const href = anchor.href;
          const ariaLabel = (anchor.getAttribute('aria-label') || '').toLowerCase();
          
          // Combine all text sources
          const allText = `${directText} ${spanTexts} ${ariaLabel}`.trim();
          
          result.push({ 
            text: allText, 
            directText,
            spanTexts,
            href, 
            ariaLabel 
          });
        }
        
        return result;
      });

      if (!links || links.length === 0) {
        logger.warn('No links found on homepage');
        return null;
      }

      logger.debug(`Found ${links.length} links on homepage`);

      // Exclude non-contact pages
      const excludeKeywords = ['career', 'job', 'press', 'media', 'blog', 'news', 'privacy', 'terms', 'legal', 'cookie'];
      
      // Search for contact-related links across all languages
      for (const link of links) {
        const searchText = link.text;
        
        // Skip invalid URLs immediately
        if (!this.isValidNavigableUrl(link.href)) {
          logger.debug(`Skipping invalid URL: ${link.href}`);
          continue;
        }
        
        // Check if any keyword list contains contact keywords
        const hasContactKeyword = Object.values(this.contactKeywords).some(keywords =>
          keywords.some(keyword => searchText.includes(keyword.toLowerCase()))
        );
        
        // Exclude non-contact pages
        const isExcluded = excludeKeywords.some(keyword => searchText.includes(keyword));
        
        if (hasContactKeyword && !isExcluded) {
          logger.info(`Found potential contact link: ${link.href}`);
          logger.debug(`Matched text: "${link.text}"`);
          
          // Verify this URL actually has a form before returning
          try {
            await existingPage.goto(link.href, {
              timeout: 15000,
              waitUntil: 'domcontentloaded'
            });
            
            const hasForm = await this.hasContactFormOnPage(existingPage);
            if (hasForm) {
              logger.info(`Verified contact page with form: ${link.href}`);
              return link.href;
            } else {
              logger.debug(`No form found on: ${link.href}`);
            }
          } catch (error) {
            logger.debug(`Could not verify link: ${link.href}`, { error: error.message });
          }
        }
      }

      logger.warn('No valid contact page found in homepage links');
      return null;

    } catch (error) {
      logger.error('Error in findByHomepageLinks:', { error: error.message });
      return null;
    }
  }

  /**
   * Find contact page using both methods
   */
  async findContactPage(homepage, existingPage = null) {
    let page = existingPage;
    const shouldClosePage = !existingPage;

    try {
      logger.info(`Finding contact page for: ${homepage}`);

      // If no page provided, create one
      if (!page) {
        page = await this.browser.newPage();
        await page.setViewport({ width: 1920, height: 1080 });
        await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      }

      // FIRST: Check if homepage itself has a contact form
      try {
        await page.goto(homepage, {
          waitUntil: 'networkidle2',
          timeout: 30000
        });

        const hasFormOnHomepage = await this.hasContactFormOnPage(page);
        if (hasFormOnHomepage) {
          logger.info(`Contact form found directly on homepage`);
          return homepage;
        }
      } catch (error) {
        logger.debug('Could not check homepage for form:', { error: error.message });
      }

      // Method 1: Analyze homepage links (primary method)
      logger.info('No form on homepage, searching for contact page links...');
      const linkResult = await this.findByHomepageLinks(homepage, page);
      if (linkResult) {
        return linkResult;
      }

      // Method 2: Try direct URLs (fallback)
      logger.info('Homepage link analysis failed, trying direct URL method...');
      const directResult = await this.findByDirectUrl(homepage, page);
      
      return directResult;

    } catch (error) {
      logger.error('Error finding contact page:', { 
        homepage, 
        error: error.message,
        stack: error.stack 
      });
      return null;
    } finally {
      // Only close if we created the page
      if (page && shouldClosePage) {
        await page.close().catch(() => {});
      }
    }
  }
}

module.exports = ContactPageFinder;