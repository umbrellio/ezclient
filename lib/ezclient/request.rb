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

    ApiAuth.sign!(api_auth_request, *args)
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

  def api_auth_request
    http_request.tap { |request| define_api_auth_header_accessors(request) }
  end

  def define_api_auth_header_accessors(request)
    # api-auth 2.x expects HTTP::Request to expose header accessors that were removed in httprb 6.
    request.define_singleton_method(:[]) { |key| headers[key] } unless request.respond_to?(:[])

    return if request.respond_to?(:[]=)

    request.define_singleton_method(:[]=) { |key, value| headers[key] = value }
  end

  def http_request
    @http_request ||= EzClient::HttprbCompatibility.build_request(
      http_client,
      verb,
      url,
      build_request_opts,
    )
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
    @http_client ||= begin
      http_client = client.dup
      http_client = set_timeout(http_client)
      http_client = EzClient::HttprbCompatibility.basic_auth(http_client, basic_auth) if basic_auth
      http_client = http_client.cookies(options[:cookies]) if options[:cookies]
      http_client
    end
  end

  def perform_request
    perform_started_at = EzClient.get_time
    with_retry do
      # Use original client so that connection can be reused
      res = client.perform(http_request, http_options)
      return res unless follow

      perform_redirects(res)
    end
  ensure
    self.elapsed_seconds = EzClient.get_time - perform_started_at
  end

  def perform_redirects(response)
    if EzClient::HttprbCompatibility.client_supports_build_request?
      redirector(follow).perform(http_request, response) { |req| client.perform(req, http_options) }
    else
      perform_redirects_with_cookies(response)
    end
  end

  def perform_redirects_with_cookies(response)
    cookie_jar = HTTP::CookieJar.new
    store_request_cookies(cookie_jar, http_request)
    store_response_cookies(cookie_jar, response)

    applied_redirects = {}.compare_by_identity
    options = follow
    options = options.merge(
      on_redirect: redirect_callback(cookie_jar, options[:on_redirect], applied_redirects),
    )

    redirector(options).perform(http_request, response) do |req|
      apply_cookies(cookie_jar, req) unless applied_redirects.delete(req)
      client.perform(req, http_options).tap do |res|
        store_response_cookies(cookie_jar, res)
      end
    end
  end

  def redirector(options)
    EzClient::HttprbCompatibility.redirector(options)
  end

  def redirect_callback(cookie_jar, callback, applied_redirects)
    proc do |response, request|
      apply_cookies(cookie_jar, request)
      applied_redirects[request] = true
      callback&.call(response, request)
    end
  end

  def store_request_cookies(cookie_jar, request)
    header = request.headers[HTTP::Headers::COOKIE].to_s

    HTTP::Cookie.cookie_value_to_hash(header).each do |name, value|
      cookie_jar.add(HTTP::Cookie.new(name, value, path: request.uri.path, domain: request.host))
    end
  end

  def store_response_cookies(cookie_jar, response)
    response.cookies.each do |cookie|
      if cookie.value == ""
        cookie_jar.delete(cookie)
      else
        cookie_jar.add(cookie)
      end
    end
  end

  def apply_cookies(cookie_jar, request)
    if cookie_jar.empty?
      request.headers.delete(HTTP::Headers::COOKIE)
    else
      cookies = cookie_jar.map { |cookie| "#{cookie.name}=#{cookie.value}" }.join("; ")
      request.headers.set(HTTP::Headers::COOKIE, cookies)
    end
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
    # This may result in 2 requests reaching the server so I hope HTTP fixes it
    # https://github.com/httprb/http/issues/459
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
