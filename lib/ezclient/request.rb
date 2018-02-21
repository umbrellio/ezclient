# frozen_string_literal: true

class EzClient::Request
  OPTION_KEYS = %i[
    body
    form
    json
    metadata
    params
    query
  ].freeze

  attr_accessor :verb, :url, :options

  def initialize(verb, url, options)
    self.verb = verb.to_s.upcase
    self.url = url
    self.client = options.delete(:client)
    self.options = options
    EzClient::CheckOptions.call(options, OPTION_KEYS + EzClient::Client::REQUEST_OPTION_KEYS)
  end

  def perform
    http_response = perform_request

    EzClient::Response.new(http_response).tap do |response|
      on_complete.call(self, response, options[:metadata])
    end
  rescue => error
    on_error.call(self, error, options[:metadata])
    raise error
  end

  def perform!
    response = perform

    if response.error?
      raise EzClient::ResponseStatusError, response
    else
      response
    end
  end

  def api_auth!(*args)
    raise "ApiAuth gem is not loaded" unless defined?(ApiAuth)
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

  def http_options
    @http_options ||= http_client.default_options.merge(ssl_context: options[:ssl_context])
  end

  private

  attr_accessor :client

  def http_request
    @http_request ||= begin
      # RUBY25: Hash#slice
      opts = options.select { |key| [:json, :body, :headers].include?(key) }
      opts[verb == "GET" ? :params : :form] = options[:params]
      opts[:params] = options[:query] if options[:query]
      opts[:form] = options[:form] if options[:form]

      http_client.build_request(verb, url, opts)
    end
  end

  def http_client
    # Only used to build proper HTTP::Request and HTTP::Options instances
    @http_client ||= begin
      http_client = client.dup
      http_client = http_client.timeout(timeout) if timeout
      http_client = http_client.basic_auth(basic_auth) if basic_auth
      http_client
    end
  end

  def perform_request
    retries = 0

    begin
      retry_on_connection_error do
        # Use original client so that connection can be reused
        client.perform(http_request, http_options)
      end
    rescue *retried_exceptions => error
      if retries < max_retries.to_i
        retries += 1
        on_retry.call(self, error, options[:metadata])
        retry
      else
        raise
      end
    end
  end

  def retry_on_connection_error
    # This may result in 2 requests reaching the server so I hope HTTP fixes it
    # https://github.com/httprb/http/issues/459
    yield
  rescue HTTP::ConnectionError => error
    on_retry.call(self, error, options[:metadata])
    yield
  end

  def timeout
    options[:timeout]&.to_f
  end

  def on_complete
    options[:on_complete] || proc {}
  end

  def on_error
    options[:on_error] || proc {}
  end

  def on_retry
    options[:on_retry] || proc {}
  end

  def retried_exceptions
    Array(options[:retry_exceptions])
  end

  def max_retries
    options[:max_retries] || 1
  end

  def basic_auth
    @basic_auth ||= begin
      case options[:basic_auth]
      when Array
        user, password = options[:basic_auth]
        { user: user, pass: password }
      when Hash
        options[:basic_auth]
      end
    end
  end
end
