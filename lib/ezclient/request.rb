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

  attr_accessor :verb, :url, :options, :elapsed_seconds

  def initialize(verb, url, options)
    self.verb = verb.to_s.upcase
    self.url = url
    self.client = options.delete(:client)
    self.options = options
    EzClient::CheckOptions.call(options, OPTION_KEYS + EzClient::Client::REQUEST_OPTION_KEYS)
  end

  def perform
    http_response = perform_request

    EzClient::Response.new(http_response, http_request).tap do |response|
      on_complete.call(self, response, options[:metadata])
    end
  rescue => error
    on_error.call(self, error, options[:metadata])
    error_wrapper.call(self, error, options[:metadata])
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

  def uri
    http_request.uri
  end

  def body
    body = +""
    http_request.body.each { |chunk| body << chunk }
    body
  end

  def headers
    http_request.headers.to_h
  end

  def add_headers!(new_headers)
    http_request.headers.merge!(new_headers)
  end

  def http_options
    @http_options ||= http_client.default_options.merge(ssl_context: options[:ssl_context])
  end

  private

  attr_accessor :client

  def http_request
    @http_request ||=
      if EzClient::HTTP_GEM_V6
        # NOTE: build_request was removed from HTTP::Client in v6; use Request::Builder instead
        merged = http_client.default_options.merge(build_request_opts)
        HTTP::Request::Builder.new(merged).build(verb, url)
      else
        http_client.build_request(verb, url, build_request_opts)
      end
  end

  def build_request_opts
    opts = {}
    opts[verb == "GET" ? :params : :form] = options[:params] if options[:params]
    opts[:json] = options[:json] if options[:json]
    opts[:body] = options[:body] if options[:body]
    opts[:params] = options[:query] if options[:query]
    opts[:form] = options[:form] if options[:form]
    opts[:form] = prepare_form_params(opts[:form]) if opts[:form]
    opts[:headers] = prepare_headers(options[:headers])
    opts
  end

  def http_client
    # NOTE: Only used to build proper HTTP::Request and HTTP::Options instances
    @http_client ||= begin
      http_client = client.dup
      http_client = set_timeout(http_client)
      if basic_auth
        # NOTE: In v6, basic_auth takes keyword args (user:, pass:);
        # NOTE: in v4/v5 it takes a positional hash
        http_client =
          if EzClient::HTTP_GEM_V6
            http_client.basic_auth(**basic_auth)
          else
            http_client.basic_auth(basic_auth)
          end
      end
      http_client = http_client.cookies(options[:cookies]) if options[:cookies]
      http_client
    end
  end

  def perform_request
    perform_started_at = EzClient.get_time
    with_retry do
      # NOTE: Use original client so that connection can be reused
      res = client.perform(http_request, http_options)
      return res unless follow

      # NOTE: In v6, Redirector.new takes keyword args; in v4/v5 it takes a positional hash
      redirector = if EzClient::HTTP_GEM_V6
                     HTTP::Redirector.new(**follow)
                   else
                     HTTP::Redirector.new(follow)
                   end
      redirector.perform(http_request, res) { |req| client.perform(req, http_options) }
    end
  ensure
    self.elapsed_seconds = EzClient.get_time - perform_started_at
  end

  def with_retry(&block)
    retries = 0

    begin
      retry_on_connection_error(&block)
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
    # NOTE: This may result in 2 requests reaching the server
    # NOTE: https://github.com/httprb/http/issues/459
    yield
  rescue HTTP::ConnectionError => error
    on_retry.call(self, error, options[:metadata])
    yield
  end

  def timeout
    case options[:timeout]
    when Hash
      options[:timeout].transform_values! { |value| value&.to_f }
    else
      options[:timeout]&.to_f
    end
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

  def follow
    return unless options[:follow]
    options[:follow].is_a?(Hash) ? options[:follow] : {}
  end

  def error_wrapper
    options[:error_wrapper] || proc { |_request, error, _metadata| raise error }
  end

  def prepare_headers(headers)
    headers = HTTP::Headers.coerce(headers)
    headers[:user_agent] ||= "ezclient/#{EzClient::VERSION}"
    headers
  end

  def prepare_form_params(original_params)
    params = {}

    # NOTE: use Hash#transform_values after Ruby 2.3 support is dropped
    original_params.each do |key, value|
      params[key] =
        if value.is_a?(File)
          HTTP::FormData::File.new(value)
        else
          value
        end
    end

    params
  end

  def set_timeout(client)
    timeout ? client.timeout(timeout) : client
  end

  def basic_auth
    @basic_auth ||=
      case options[:basic_auth]
      when Array
        user, password = options[:basic_auth]
        { user: user, pass: password }
      when Hash
        options[:basic_auth]
      end
  end
end
