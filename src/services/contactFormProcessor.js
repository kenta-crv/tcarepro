const puppeteer = require('puppeteer');
const logger = require('../config/logger');
const ContactPageFinder = require('./contactPageFinder');
const FormAnalyzer = require('./formAnalyzer');
const FormSubmitter = require('./formSubmitter');
const UrlDetector = require('../utils/urlDetector');
const ResultsManager = require('../utils/resultsManager');
const ProcessTracker = require('../utils/processTracker');

class ContactFormProcessor {
  constructor() {
    this.browser = null;
    this.urlDetector = null;
    this.resultsManager = new ResultsManager();
    this.processTracker = new ProcessTracker();
  }

  /**
   * Initialize browser and URL detector
   */
  async init() {
    try {
      logger.info('Initializing Puppeteer browser...');
      
      this.browser = await puppeteer.launch({
        headless: process.env.HEADLESS === 'true',
        args: [
          '--no-sandbox',
          '--disable-setuid-sandbox',
          '--disable-dev-shm-usage',
          '--disable-accelerated-2d-canvas',
          '--disable-gpu',
          '--window-size=1920x1080'
        ],
        defaultViewport: {
          width: 1920,
          height: 1080
        },
        ignoreHTTPSErrors: true
      });

      logger.info('Browser initialized successfully');

      // Initialize URL detector with browser instance for enhanced detection
      this.urlDetector = new UrlDetector(this.browser);
      logger.info('URL detector initialized with Puppeteer support');

      // Load processed companies
      await this.processTracker.load();

    } catch (error) {
      logger.error('Failed to initialize browser:', { 
        error: error.message,
        stack: error.stack 
      });
      throw error;
    }
  }

  /**
   * Close browser
   */
  async close() {
    if (this.browser) {
      try {
        await this.browser.close();
        logger.info('Browser closed successfully');
      } catch (error) {
        logger.error('Error closing browser:', { error: error.message });
      }
    }
  }

  /**
   * Process a single company
   */
  async processCompany(company) {
    const startTime = Date.now();
    let page = null; // Single page instance for entire workflow
    
    logger.info('='.repeat(70));
    logger.info(`Processing: ${company.name} (ID: ${company.id})`);
    logger.info('='.repeat(70));

    try {
      // Create ONE page for the entire workflow
      page = await this.browser.newPage();
      await page.setViewport({ width: 1920, height: 1080 });
      await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');

      // Step 1: Determine homepage URL
      let homepage = null;
      if (company.url) {
        homepage = UrlDetector.normalizeUrl(company.url);
        logger.info(`Using url as homepage: ${homepage}`);
      } else {
        logger.info('No URL provided, attempting to detect website...');
        homepage = await this.urlDetector.detectWebsite(company.name);
        
        if (!homepage) {
          throw new Error('Could not detect company website');
        }
        logger.info(`Detected homepage: ${homepage}`);
      }

      logger.info(`Final homepage: ${homepage}`);

      // Test if homepage is accessible before proceeding
      try {
        const testResponse = await page.goto(homepage, {
          waitUntil: 'domcontentloaded',
          timeout: 15000
        });

        if (!testResponse || testResponse.status() === 0) {
          throw new Error('Site unreachable - possible certificate error');
        }
      } catch (testError) {
        if (testError.message.includes('ERR_CERT_') || 
            testError.message.includes('SSL') || 
            testError.message.includes('certificate')) {
          
          const processingTime = Date.now() - startTime;
          const result = {
            id: company.id,
            name: company.name,
            homepage: homepage,
            contact_form_url: null,
            status: 'SKIPPED',
            message: 'SSL/Certificate error - site unreachable',
            error_details: testError.message,
            processing_time_ms: processingTime,
            timestamp: new Date().toISOString()
          };

          logger.error(`Skipping company ${company.name}: Certificate error`);
          await this.resultsManager.saveResult(result);
          await this.processTracker.saveProcessedCompany(company.id, 'SKIPPED', homepage);
          
          return result;
        }
        throw testError;
      }

      // Step 2: Determine contact form URL
      let contactFormUrl = null;
      
      // If contact_url is provided AND not empty, use it directly as the contact form URL
      if (company.contact_url && company.contact_url.trim()) {
        logger.info('Contact form URL provided directly');
        contactFormUrl = UrlDetector.normalizeUrl(company.contact_url);
        logger.info(`Using provided contact_url: ${contactFormUrl}`);
      }
      
      // If no contact_url provided, find contact page from homepage
      if (!contactFormUrl) {
        logger.info('Searching for contact page from homepage...');
        const finder = new ContactPageFinder(this.browser);
        contactFormUrl = await finder.findContactPage(homepage, page);
        
        if (!contactFormUrl) {
          const processingTime = Date.now() - startTime;
          const result = {
            id: company.id,
            name: company.name,
            homepage: homepage,
            contact_form_url: null,
            status: 'SKIPPED',
            message: 'Could not find contact page',
            processing_time_ms: processingTime,
            timestamp: new Date().toISOString()
          };

          logger.warn(`Skipping company ${company.name}: Contact page not found`);
          await this.resultsManager.saveResult(result);
          await this.processTracker.saveProcessedCompany(company.id, 'SKIPPED', homepage);
          
          return result;
        }
      }

      logger.info(`Contact form URL: ${contactFormUrl}`);

      // Step 3: Analyze form
      logger.info('Analyzing contact form...');
      const analyzer = new FormAnalyzer(this.browser);
      
      // FIXED: Pass parameters in correct order: url, baseUrl (for relative URL resolution), existingPage
      const formAnalysis = await analyzer.analyzeForm(
        contactFormUrl,
        homepage,  // baseUrl for resolving relative URLs
        page       // existingPage to reuse current page
      );
      
      if (!formAnalysis.contactForm) {
        const processingTime = Date.now() - startTime;
        const result = {
          id: company.id,
          name: company.name,
          homepage: homepage,
          contact_form_url: contactFormUrl,
          status: 'SKIPPED',
          message: 'No suitable contact form found on page',
          processing_time_ms: processingTime,
          timestamp: new Date().toISOString()
        };

        logger.warn(`Skipping company ${company.name}: No suitable contact form found`);
        await this.resultsManager.saveResult(result);
        await this.processTracker.saveProcessedCompany(company.id, 'SKIPPED', homepage);
        
        return result;
      }

      logger.info(`Found contact form with ${formAnalysis.contactForm.inputs.length} fields`);

      // Step 4: Fill and submit form
      logger.info('Filling and submitting form...');
      const submitter = new FormSubmitter(this.browser);
      const submissionResult = await submitter.submitForm(
        contactFormUrl, 
        formAnalysis.contactForm,
        page // Pass existing page
      );

      // Calculate processing time
      const processingTime = Date.now() - startTime;

      // Build result object
      const result = {
        id: company.id,
        name: company.name,
        homepage: homepage,
        contact_form_url: contactFormUrl,
        contact_form_detected: !company.contact_url,
        form_analysis: {
          total_forms_found: formAnalysis.totalForms,
          contact_form_score: formAnalysis.contactForm.score,
          input_fields_count: formAnalysis.contactForm.inputs.length,
          input_fields: formAnalysis.contactForm.inputs.map(f => ({
            name: f.name,
            type: f.type,
            fieldType: f.fieldType,
            required: f.required,
            label: f.label
          }))
        },
        submission: submissionResult,
        status: submissionResult.success ? 'SUCCESS' : 'FAILED',
        processing_time_ms: processingTime,
        timestamp: new Date().toISOString()
      };

      // Log result summary
      this.logResultSummary(result);

      // Save result
      await this.resultsManager.saveResult(result);

      // Save to process tracker
      await this.processTracker.saveProcessedCompany(company.id, result.status, result.homepage);

      return result;

    } catch (error) {
      logger.error(`Failed to process company ${company.name}:`, { 
        error: error.message,
        stack: error.stack 
      });

      const processingTime = Date.now() - startTime;

      const result = {
        id: company.id,
        name: company.name,
        homepage: company.url || null,
        contact_form_url: null,
        status: 'ERROR',
        error: error.message,
        processing_time_ms: processingTime,
        timestamp: new Date().toISOString()
      };

      await this.resultsManager.saveResult(result);
      await this.processTracker.saveProcessedCompany(company.id, 'ERROR', result.homepage);

      return result;
    } finally {
      // Close the single page after entire workflow
      if (page) {
        await page.close().catch(() => {});
        logger.info('Page closed after company processing');
      }
    }
  }

  /**
   * Log result summary
   */
  logResultSummary(result) {
    logger.info('-'.repeat(70));
    logger.info('RESULT SUMMARY:');
    logger.info(`  Company: ${result.name}`);
    logger.info(`  Status: ${result.status}`);
    logger.info(`  Homepage: ${result.homepage}`);
    logger.info(`  Contact URL: ${result.contact_form_url || 'N/A'}`);
    
    if (result.form_analysis) {
      logger.info(`  Form Fields: ${result.form_analysis.input_fields_count}`);
    }
    
    if (result.submission) {
      logger.info(`  Form Submitted: ${result.submission.success}`);
      logger.info(`  Success Detected: ${result.submission.successDetected || false}`);
      logger.info(`  Has CAPTCHA: ${result.submission.hasCaptcha || false}`);
    }
    
    logger.info(`  Processing Time: ${result.processing_time_ms}ms`);
    logger.info('-'.repeat(70));
  }

  /**
   * Process multiple companies
   */
  async processCompanies(companies) {
    await this.init();

    const results = [];
    const delay = parseInt(process.env.QUEUE_DELAY_BETWEEN_JOBS) || 2000;

    try {
      for (let i = 0; i < companies.length; i++) {
        const company = companies[i];
        
        logger.info(`\nProcessing ${i + 1}/${companies.length}...`);
        
        const result = await this.processCompany(company);
        results.push(result);

        // Delay between requests
        if (i < companies.length - 1) {
          logger.info(`Waiting ${delay}ms before next request...`);
          await new Promise(resolve => setTimeout(resolve, delay));
        }
      }

      // Generate final report
      await this.resultsManager.generateReport(results);

      return results;

    } finally {
      await this.close();
    }
  }
}

module.exports = ContactFormProcessor;