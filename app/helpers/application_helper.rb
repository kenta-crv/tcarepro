module ApplicationHelper
  def default_meta_tags
    {
      site: "営業で最高の結果を出せるマーケティングリストなら『TCARE』",
      title:"<%= yield(:title) | TCARE' %>",
      description: "営業で最高の結果を出せるマーケティングリストなら『TCARE』。『イマ』ニーズのある企業情報を提供します。",
      keywords: "営業リスト,マーケティングリスト",
      canonical: request.original_url,  # 優先されるurl
      charset: "UTF-8",
      reverse: true,
      separator: '|',
      icon: [
        { href: image_url('favicon.ico') },
        { href: image_url('favicon.ico'),  rel: 'apple-touch-icon' },
      ],
    }
  end
end
