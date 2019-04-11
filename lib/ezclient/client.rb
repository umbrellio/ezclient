# frozen_string_literal: true

class EzClient::Client
  REQUEST_OPTION_KEYS = %i[
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
  ].freeze

  def initialize(options = {})
    self.request_options = options
    EzClient::CheckOptions.call(options, REQUEST_OPTION_KEYS)
  end

  def request(verb, url, **options)
    options = { **request_options, **options }

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

  def perform(*args)
    request(*args).perform
  end

  def perform!(*args)
    request(*args).perform!
  end

  private

  attr_accessor :request_options

  def persistent_client_for(url, timeout: 600)
    uri = HTTP::URI.parse(url)
    persistent_clients = (Thread.current[:"__ezclient_persistent_clients_#{object_id}"] ||= {})
    persistent_clients[uri.origin] ||= HTTP.persistent(uri.origin, timeout: timeout)
  end
end
