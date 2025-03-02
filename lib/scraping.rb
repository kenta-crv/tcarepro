require 'open-uri'
require 'nokogiri'
require 'timeout'

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
  
    begin
      # 1) URLパース（URLエンコードしない）
      customer_url = URI.parse(url)
  
      # 2) ドメインがブラックリストに入っている場合は無視
      if customer_url.host.present? && BLACKLIST_DOMAINS.include?(customer_url.host)
        return nil
      end
  
      # 3) NokogiriでHTMLドキュメントを取得
      #    （create_document の中でオープンやタイムアウト処理している想定）
      document, final_url = create_document(url)

      if document.nil?
        # `/index.html` を削除してもダメだった場合 → `/` 以降を削除し、ルートを試す
        parent_url = url.sub(%r{/[^/]+$}, '/')
        Rails.logger.info("[contact_from] Retrying with parent URL: #{parent_url}")
  
        document, final_url = create_document(parent_url)
      end

      if document.nil?
        # `/index.html` を削除してもダメだった場合 → `/` 以降を削除し、ルートを試す
        parent_url = url.sub(%r{/[^/]+$}, '/')
        fallback_url = parent_url[0...-1]  # 最後の1文字を削除
        Rails.logger.info("[contact_from] Retrying with parent URL: #{fallback_url}")
  
        document, final_url = create_document(fallback_url)
      end

      return nil unless document
  
      # 4) 検索する文字列を拡張
      #    - 「お問合せ」「お問い合わせ」「問合せ」「問い合わせ」「contact」「CONTACT」など
      contact_pattern = /お問合せ|お問い合わせ|お問い合せ|お問合わせ|問合せ|問い合わせ|問い合せ|問合わせ|contact/i
  
      # 全要素を走査
      document.css('*').each do |node|
        next if node.text.blank? && node['alt'].blank?

        # テキスト + alt属性 をまとめて検索用文字列にする
        combined_text = [node.text, node['alt']].compact.join(' ')

        # 「問い合わせ」等を含むか？
        if combined_text =~ contact_pattern
          # -----------------------------
          # 1) node自身が <a> なら href を返す
          # -----------------------------
          if node.name == 'a'
            href_raw = node['href'].to_s.strip
            return fix_relative_path(final_url, href_raw)
          end

          # -----------------------------
          # 2) 先祖(ancestor)に <a> があれば href を返す
          # -----------------------------
          anchor = node.ancestors('a').first
          if anchor
            href_raw = anchor['href'].to_s.strip
            return fix_relative_path(final_url, href_raw)
          end

          # -----------------------------
          # 3) 先祖に <form> があれば action を返す
          #    （問い合わせフォーム自体を探したい場合）
          # -----------------------------
          form = node.ancestors('form').first
          if form
            action_raw = form['action'].to_s.strip
            return fix_relative_path(final_url, action_raw)
          end

          # ※もし「最初の一致だけでなく全部欲しい」なら、
          #   配列に push して最後にまとめて返すように変更する
        end
      end
    rescue StandardError => e
      Rails.logger.info("[contact_from] #{e.class}: #{e.message} [url] #{final_url}")
    end
  
    # 見つからなければ nil
    nil
  end

  # 相対パスを絶対URLに直すためのヘルパー
  def fix_relative_path(base_url, href_raw)
    return nil if href_raw.blank?

    base_uri = URI.parse(base_url)
    href_uri = URI.parse(href_raw) rescue nil
    return nil unless href_uri

    if href_uri.scheme.blank? && href_uri.host.blank?
      # 相対パス → 絶対パスに補完
      href_uri.scheme = base_uri.scheme
      href_uri.host   = base_uri.host
      # '/' で始まってない場合は付け足し（適宜お好みで）
      href_uri.path = '/' + href_uri.path unless href_uri.path.start_with?('/')
    end

    href_uri.to_s
  end

  #
  # contact_url から入力要素を抽出する
  #
  # @param [String] url URL
  #
  # @return [Hash] 入力要素
  #
  def input_attributes(url)
    document, final_url = create_document(url)

    return nil unless document

    form = document.css('form')
    elements = form.css('input', 'textarea', 'select').map do |element|
      element unless ['hidden', 'submit', 'reset'].include?(element.get_attribute('type'))
    end.compact

    elements.select! { |element| element.get_attribute('name').present? }

    elements.map do |element|
      if element.get_attribute('id')
        label = form.search("label[for='#{element.get_attribute('id')}']")&.inner_html
      end

      unless label.present?
        parent = element.parent
        parent = element.parent if parent.name != 'tr'
        parent = parent.parent if parent.name != 'tr'

        if parent.name == 'tr'
          label = parent.at_css('th,td').inner_html
        end
      end

      {
        'id' => element.get_attribute('id'),
        'name' => element.get_attribute('name'),
        'tag' => element.name,
        'class' => element.get_attribute('class'),
        'type' => element.get_attribute('type'),
        'value' => element.get_attribute('value'),
        'label' => label&.encode('utf-8')&.gsub(/(\r\n?|\n|[[:space:]])/,""),
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
    begin
      document, final_url = create_document(
        "https://www.google.co.jp/search?hl=ja&num=11&q=#{URI.encode_www_form_component(keyword)}"
      )
      anchor = document.css('div.kCrYT > a')[0].get_attribute('href')
      URI::decode_www_form(URI.parse(anchor).query)[0][1]
    rescue
      Rails.logger.info("デコードエラー")
    end
  end

  private

  def create_document(url)
    return [nil, nil] unless url.is_a?(String) && !url.strip.empty?
  
    io = Timeout.timeout(5) { URI.open(url, allow_redirections: :all) }
    final_url = io.base_uri.to_s
    doc = Nokogiri::HTML(io)
    [doc, final_url]
  rescue Encoding::CompatibilityError, Encoding::UndefinedConversionError
    io = Timeout.timeout(5) { URI.open(url, 'r:Shift_JIS', allow_redirections: :all) }
    final_url = io.base_uri.to_s
    doc = Nokogiri::HTML(io)
    [doc, final_url]
  rescue OpenURI::HTTPError, SocketError, Errno::ENOENT, OpenSSL::SSL::SSLError,
         Timeout::Error, ArgumentError, EOFError, Errno::ECONNREFUSED => e
    Rails.logger.error("[url] #{url} [message] #{e.class}: #{e}")
    [nil, nil]
  end
  
  
  


  attr_reader :customer
end
