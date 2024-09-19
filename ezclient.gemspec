# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "ezclient/version"

Gem::Specification.new do |spec|
  spec.required_ruby_version = ">= 3.0"

  spec.name = "ezclient"
  spec.version = EzClient::VERSION
  spec.authors = ["Yuri Smirnov"]
  spec.email = ["tycooon@yandex.ru", "oss@umbrellio.biz"]

  spec.summary = "An HTTP gem wrapper for easy persistent connections and more."
  spec.homepage = "https://github.com/umbrellio/ezclient"
  spec.license = "MIT"

  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^spec/}) }
  spec.require_paths = ["lib"]

  spec.add_dependency "http", ">= 4"
end
