# -*- encoding: utf-8 -*-
# stub: thinreports 0.12.0 ruby lib

Gem::Specification.new do |s|
  s.name = "thinreports".freeze
  s.version = "0.12.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Matsukei Co.,Ltd.".freeze]
  s.date = "2021-01-16"
  s.description = "Thinreports is an open source report generation tool for Ruby.".freeze
  s.email = "thinreports@gmail.com".freeze
  s.homepage = "http://www.thinreports.org".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.5.0".freeze)
  s.rubygems_version = "3.0.1".freeze
  s.summary = "An open source report generation tool for Ruby.".freeze

  s.installed_by_version = "3.0.1" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<prawn>.freeze, ["~> 2.2"])
      s.add_runtime_dependency(%q<rexml>.freeze, [">= 0"])
      s.add_development_dependency(%q<minitest>.freeze, [">= 5.14.1"])
      s.add_development_dependency(%q<mocha>.freeze, [">= 1.11.2"])
      s.add_development_dependency(%q<pdf-inspector>.freeze, [">= 1.3.0"])
      s.add_development_dependency(%q<rake>.freeze, [">= 13.0.1"])
    else
      s.add_dependency(%q<prawn>.freeze, ["~> 2.2"])
      s.add_dependency(%q<rexml>.freeze, [">= 0"])
      s.add_dependency(%q<minitest>.freeze, [">= 5.14.1"])
      s.add_dependency(%q<mocha>.freeze, [">= 1.11.2"])
      s.add_dependency(%q<pdf-inspector>.freeze, [">= 1.3.0"])
      s.add_dependency(%q<rake>.freeze, [">= 13.0.1"])
    end
  else
    s.add_dependency(%q<prawn>.freeze, ["~> 2.2"])
    s.add_dependency(%q<rexml>.freeze, [">= 0"])
    s.add_dependency(%q<minitest>.freeze, [">= 5.14.1"])
    s.add_dependency(%q<mocha>.freeze, [">= 1.11.2"])
    s.add_dependency(%q<pdf-inspector>.freeze, [">= 1.3.0"])
    s.add_dependency(%q<rake>.freeze, [">= 13.0.1"])
  end
end
