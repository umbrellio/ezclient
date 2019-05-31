# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "ezclient/version"

Gem::Specification.new do |spec|
  spec.required_ruby_version = ">= 2.3.8"

  spec.name    = "ezclient"
  spec.version = EzClient::VERSION
  spec.authors = ["Yuri Smirnov"]
  spec.email   = ["tycooon@yandex.ru", "oss@umbrellio.biz"]

  spec.summary  = "An HTTP gem wrapper for easy persistent connections and more."
  spec.homepage = "https://github.com/umbrellio/ezclient"
  spec.license  = "MIT"

  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^spec/}) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "http", ">= 4"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "coveralls"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rubocop-config-umbrellio"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "webmock"
end
