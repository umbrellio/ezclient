# frozen_string_literal: true

require "simplecov"
require "simplecov-lcov"
require "pry"

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

# WebMock (up to at least 3.24.0) has two incompatibilities with httprb v6:
#
# 1. HTTP::Response.new changed from accepting a positional Hash to keyword arguments.
#    WebMock calls `new({status: ..., version: ..., ...})` which raises ArgumentError in v6.
#
# 2. HTTP::Response::Body#read_contents (and #readpartial) expect the underlying stream's
#    #readpartial to raise EOFError at end-of-stream (per the v6 IO#readpartial contract),
#    but WebMock's Streamer returns nil, causing TypeError: no implicit conversion of nil
#    into String.
unless EzClient::HTTP_CLIENT_SUPPORTS_BUILD_REQUEST
  module HTTP
    class Response
      class << self
        def from_webmock(request, webmock_response, _request_signature = nil)
          status  = Status.new(webmock_response.status.first)
          headers = webmock_response.headers || {}
          body    = build_http_rb_response_body_from_webmock_response(webmock_response)

          new(
            status: status,
            version: "1.1",
            headers: headers,
            body: body,
            request: request,
          )
        end
      end
    end

    class Response
      class Streamer
        # httprb v6 requires readpartial to raise EOFError at end-of-stream instead of returning nil
        def readpartial(size = nil, outbuf = nil)
          raise EOFError, "end of stream reached" if @io.eof?

          chunk = size ? @io.read(size, outbuf) : @io.read
          raise EOFError, "end of stream reached" if chunk.nil?

          chunk.force_encoding(@encoding)
        end
      end
    end
  end
end

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
