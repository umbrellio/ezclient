# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "ezclient/version"

Gem::Specification.new do |spec|
  spec.name          = "ezclient"
  spec.version       = EzClient::VERSION
  spec.authors       = ["Yuri Smirnov"]
  spec.email         = ["tycooon@yandex.ru"]

  spec.summary       = "An HTTP gem wrapper for easy persistent connections and more."
  spec.homepage      = "https://github.org/umbrellio/ezclient"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^spec/}) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "http", ">= 4.0.0dev"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "coveralls"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rubocop-config-umbrellio"
  spec.add_development_dependency "simplecov"
end
