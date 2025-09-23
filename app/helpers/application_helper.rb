module ApplicationHelper
  def default_meta_tags
    {
      site: "営業リストで最高の結果を出すならマーケティングリストの『TCARE』",
      title:"<%= yield(:title) | TCARE' %>",
      description: "営業リストで最高の結果を出すならマーケティングリストの『TCARE』。マーケティングで成功する営業リストを提供します。",
      canonical: request.original_url,  # 優先されるurl
      charset: "UTF-8",
      reverse: true,
      separator: '|',
      icon: [
        { href: image_url('favicon.ico') },
        { href: image_url('favicon.ico'),  rel: 'apple-touch-icon' },
      ]
    }
  end
  # In app/helpers/application_helper.rb
  def smart_image_tag(source, options = {})
    if Rails.application.config.assets.enabled
      image_tag(source, options)
    else
      # Fallback to direct path when assets are disabled
      tag.img(options.merge(src: "/images/#{source}"))
    end
  end
end
