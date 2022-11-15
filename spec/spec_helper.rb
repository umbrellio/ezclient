# frozen_string_literal: true

require "simplecov"
require "simplecov-lcov"

SimpleCov::Formatter::LcovFormatter.config do |config|
  config.report_with_single_file = true
  config.single_report_path = "coverage/lcov.info"
end

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::LcovFormatter,
])

SimpleCov.start

require "webmock/rspec"
require "ezclient"

RSpec.configure do |config|
  config.order = :random
  Kernel.srand config.seed

  config.example_status_persistence_file_path = ".rspec_status"

  config.disable_monkey_patching!
  config.raise_errors_for_deprecations!

  config.expect_with(:rspec) { |c| c.syntax = :expect }

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
