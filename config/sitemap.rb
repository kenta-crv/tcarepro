# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = "https://tcare.pro"

SitemapGenerator::Sitemap.sitemaps_path = 'sitemaps/'

SitemapGenerator::Sitemap.create do
add "/" , changefreq: 'daily', priority: 1.0

  add customers_path, :priority => 1.0, :changefreq => 'daily'
  Customer.find_each do |customer|
    add customer_path(customer), :lastmod => customer.updated_at
  end
end
