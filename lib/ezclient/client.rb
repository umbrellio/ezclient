# frozen_string_literal: true
# typed: strict

class EzClient::Client
  REQUEST_OPTION_KEYS = T.let(%i[
    api_auth
    basic_auth
    cookies
    headers
    keep_alive
    max_retries
    on_complete
    on_error
    on_retry
    retry_exceptions
    ssl_context
    timeout
    follow
  ].freeze, T::Array[Symbol])

  def initialize(options = {})
    @request_options = T.let(options, T::Hash[Symbol, T.untyped])
    @clients = T.let({}, T::Hash[Symbol, T.untyped])
    EzClient::CheckOptions.call(options, REQUEST_OPTION_KEYS)
  end

  def request(verb, url, options = {})
    options = { **@request_options, **options }

    keep_alive_timeout = options.delete(:keep_alive)
    api_auth = options.delete(:api_auth)

    if keep_alive_timeout
      client = persistent_client_for(url, timeout: keep_alive_timeout)
    else
      client = HTTP::Client.new
    end

    EzClient::Request.new(verb, url, client: client, **options).tap do |request|
      request.api_auth!(*api_auth) if api_auth
    end
  end

  def perform(verb, url, options = {})
    request(verb, url, options).perform
  end

  def perform!(verb, url, options = {})
    request(verb, url, options).perform!
  end

  private

  def persistent_client_for(url, timeout: 600)
    uri = HTTP::URI.parse(url)
    @clients[uri.origin] ||= HTTP.persistent(uri.origin, timeout: timeout)
  end
end
