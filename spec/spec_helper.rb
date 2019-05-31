# frozen_string_literal: true

require "simplecov"
require "coveralls"

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter,
])

SimpleCov.start { add_filter "spec" }

require "bundler/setup"
require "webmock/rspec"
require "ezclient"

RSpec.configure do |config|
  config.order = :random
  Kernel.srand config.seed
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
