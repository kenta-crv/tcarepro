# -*- encoding: utf-8 -*-
# stub: simple_enum 2.3.2 ruby lib

Gem::Specification.new do |s|
  s.name = "simple_enum".freeze
  s.version = "2.3.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 2.0.0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Lukas Westermann".freeze]
  s.date = "2018-07-02"
  s.description = "Provides enum-like fields for ActiveRecord, ActiveModel and Mongoid models.".freeze
  s.email = ["lukas.westermann@gmail.com".freeze]
  s.homepage = "http://lwe.github.com/simple_enum/".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3".freeze)
  s.rubygems_version = "3.3.5".freeze
  s.summary = "Simple enum-like field support for models.".freeze

  s.installed_by_version = "3.3.5" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<activesupport>.freeze, [">= 4.0.0"])
    s.add_development_dependency(%q<rake>.freeze, [">= 10.1.0"])
    s.add_development_dependency(%q<activerecord>.freeze, [">= 4.0.0"])
    s.add_development_dependency(%q<mongoid>.freeze, [">= 4.0.0"])
    s.add_development_dependency(%q<rspec>.freeze, ["~> 2.14"])
  else
    s.add_dependency(%q<activesupport>.freeze, [">= 4.0.0"])
    s.add_dependency(%q<rake>.freeze, [">= 10.1.0"])
    s.add_dependency(%q<activerecord>.freeze, [">= 4.0.0"])
    s.add_dependency(%q<mongoid>.freeze, [">= 4.0.0"])
    s.add_dependency(%q<rspec>.freeze, ["~> 2.14"])
  end
end
