require 'open-uri'
require 'nokogiri'

class Scraping
  BLACKLIST_DOMAINS = [
    'jp.indeed.com',
    'xn--pckua2a7gp15o89zb.com',
  ]

  #
  # url から問い合わせ先の URL を取得する
  #
  # @param [String] url URL
  #
  # @return [String] 問い合わせ URL
  #
  def contact_from(url)
    return nil if url.blank?

    customer_url = URI.parse(URI.encode(url))

    return nil if BLACKLIST_DOMAINS.include?(customer_url.host)

    document = create_document(url)

    return nil unless document

    document.css('a').each do |anchor|
      next unless anchor.get_attribute('href')

      # anchor.inner_html.encode('utf-8') + anchor.get_attribute('alt')
      if anchor.inner_html.encode('utf-8') =~ /問い合わせ|問合せ/
        href = URI.parse(URI.encode(anchor.get_attribute('href')))

        if !href.host && !href.scheme
          unless href.path[0] == '/'
            href.path = customer_url.path + href.path
          end

          href.scheme = customer_url.scheme
          href.host = customer_url.host
        end

        return href.to_s
      end
    end

    nil
  rescue Net::OpenTimeout, Net::ReadTimeout
    nil
  rescue Encoding::CompatibilityError
    nil
  rescue ArgumentError
    nil
  end

  #
  # contact_url から入力要素を抽出する
  #
  # @param [String] url URL
  #
  # @return [Hash] 入力要素
  #
  def input_attributes(url)
    document = create_document(url)

    return nil unless document

    form = document.css('form')
    elements = form.css('input', 'textarea', 'select').map do |element|
      element unless ['hidden', 'submit', 'reset'].include?(element.get_attribute('type'))
    end.compact

    elements.map do |element|
      {
        'id' => element.get_attribute('id'),
        'name' => element.get_attribute('name'),
        'class' => element.get_attribute('class'),
        'type' => element.get_attribute('type'),
        'value' => element.get_attribute('value'),
      }
    end
  end

  #
  # Google を検索し、最初の１件を検索する
  #
  # @param [String] keyword 検索するキーワード
  #
  # @return [String] URL
  #
  def google_search(keyword)
    document = create_document(
      "https://www.google.co.jp/search?hl=ja&num=11&q=#{URI.encode_www_form_component(keyword)}"
    )
    anchor = document.css('div.kCrYT > a')[0].get_attribute('href')

    URI::decode_www_form(URI.parse(anchor).query)[0][1]
  end

  private

  def create_document(url)
    Nokogiri::HTML(URI.open(url, :allow_redirections => :all))
  rescue Encoding::CompatibilityError
    Nokogiri::HTML(URI.open(url, 'r:Shift_JIS', :allow_redirections => :all))
  rescue OpenURI::HTTPError, SocketError, Errno::ENOENT, OpenSSL::SSL::SSLError
    Rails.logger.error url
    Rails.logger.error $!

    nil
  rescue ArgumentError
    Rails.logger.error url
    Rails.logger.error $!.backtrace.join("\n")

    nil
  end

  attr_reader :customer
end
