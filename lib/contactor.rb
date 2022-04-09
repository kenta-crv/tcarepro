class Contactor
  def initialize(inquiry, sender)
    @inquiry = inquiry
    @sender = sender
  end

  #
  # contact_url から属性を抽出し、inquiry と tracking_code を対応付けする
  #
  # @param [String] contact_url お問い合わせ URL
  # @param [String] customer_id 顧客 ID
  #
  # @return [Hash] 属性と値の対応付け結果
  #
  def try_typings(contact_url, customer_id)
    return nil if contact_url.blank?

    attributes = scraping.input_attributes(contact_url)

    return nil if attributes.blank?

    attributes.map do |attribute|
      name_mapping = NameMapping.find_key(attribute['name'], attribute['label'])

      if name_mapping
        if name_mapping.key == 'content'
          value = inquiry.parse_content(sender, customer_id)
        else
          value = inquiry.attributes[name_mapping.key]
        end
      end
  
      [attribute['name'], value && { 'value' => value, 'attributes' => attribute }]
    end.to_h.compact
  end

  def send_contact(contact_url, customer_id)
    driver.get(contact_url)

    try_typings(contact_url, customer_id)&.each do |key, typing|
      begin
        next if ['select'].include?(typing['attributes']['tag'])
        next if ['submit', 'reset', 'button', 'image', 'radio', 'checkbox'].include?(typing['attributes']['type'])

        driver.find_element(:name, key).send_keys(typing['value'])
      rescue Selenium::WebDriver::Error::ElementNotInteractableError,
             Selenium::WebDriver::Error::UnexpectedAlertOpenError,
             Selenium::WebDriver::Error::InvalidArgumentError
        Rails.logger.warn("[name] #{key} [value] #{typing['value']} [message] #{$!.class}: #{$!.to_s}")
      rescue
        Rails.logger.fatal("[name] #{key} [value] #{typing['value']} [message] #{$!.class}: #{$!.to_s}")
      end
    end
  rescue Net::ReadTimeout, Selenium::WebDriver::Error::UnknownError
    Rails.logger.fatal("[name] #{key} [value] #{typing['value']} [message] #{$!.class}: #{$!.to_s}")
  end

  def screenshot(screenshot_path)
    driver.manage.window.resize_to(
      driver.execute_script("return document.body.scrollWidth;"),
      driver.execute_script("return document.body.scrollHeight;"),
    )

    driver.save_screenshot(screenshot_path)
  rescue Selenium::WebDriver::Error::UnexpectedAlertOpenError
    Rails.logger.fatal("[message] #{$!.class}: #{$!.to_s}")
  end

  private

  def driver
    unless @driver
      options = Selenium::WebDriver::Chrome::Options.new

      options.add_argument('--headless') unless ENV['VISIBLE'] == 'true'

      @driver = Selenium::WebDriver.for(:chrome, options: options)
    end
    @driver
  end

  def scraping
    @scraping ||= Scraping.new
  end

  attr_reader :inquiry, :sender
end
