# frozen_string_literal: true

class EzClient::Request
  DEFAULT_TIMEOUT = 15

  attr_accessor :verb, :url, :options

  def initialize(verb, url, options)
    self.verb = verb.to_s.upcase
    self.url = url
    self.options = options
  end

  def perform
    http_response = http_client.perform(http_request, http_client.default_options)

    EzClient::Response.new(http_response).tap do |response|
      on_complete.call(self, response, options[:metadata])
    end
  rescue => error
    on_error.call(self, error, options[:metadata])
    raise error
  end

  def api_auth!(*args)
    # raise "ApiAuth gem is not loaded" unless defined?(ApiAuth)
    ApiAuth.sign!(http_request, *args)
    self
  end

  def body
    http_request.body.source.rewind if http_request.body.source.respond_to?(:rewind)
    body = +""
    http_request.body.each { |chunk| body << chunk }
    body
  end

  def headers
    http_request.headers.to_h
  end

  private

  def http_client
    options.fetch(:client).timeout(timeout)
  end

  def timeout
    options.fetch(:timeout, DEFAULT_TIMEOUT).to_f
  end

  def http_request
    @http_request ||= http_client.build_request(verb, url, http_options)
  end

  def http_options
    # RUBY25: Hash#slice
    options.select { |key| [:params, :form, :json, :body, :headers].include?(key) }
  end

  def on_complete
    options[:on_complete] || proc {}
  end

  def on_error
    options[:on_error] || proc {}
  end
end
