# frozen_string_literal: true

class EzClient::Client
  REQUEST_OPTION_KEYS = %i[
    api_auth
    basic_auth
    cleanup_interval
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
    error_wrapper
  ].freeze

  def initialize(options = {})
    self.request_options = options
    EzClient::CheckOptions.call(options, REQUEST_OPTION_KEYS)
    self.persistent_client_registry = EzClient::PersistentClientRegistry.build_for_client(
      cleanup_interval: options[:cleanup_interval]
    )
  end

  def request(verb, url, **options)
    options = { **request_options, **options }

    keep_alive_timeout = options.delete(:keep_alive)
    api_auth = options.delete(:api_auth)
    ssl_context = options[:ssl_context]

    if keep_alive_timeout
      client = persistent_client_registry.for(
        url, ssl_context:, timeout: keep_alive_timeout
      )
    else
      client = HTTP::Client.new
    end

    EzClient::Request.new(verb, url, client:, **options).tap do |request|
      request.api_auth!(*api_auth) if api_auth
    end
  end

  def perform(*args, **kwargs)
    request(*args, **kwargs).perform
  end

  def perform!(*args, **kwargs)
    request(*args, **kwargs).perform!
  end

  def truncate!
    persistent_client_registry.truncate!
  end

  private

  attr_accessor :request_options, :persistent_client_registry
end
