# frozen_string_literal: true

class EzClient::Client
  def initialize(options = {})
    self.options = options
    self.clients = {}
  end

  def request(verb, url, **options)
    options = { **default_options, **options } # TODO: raise on unknown options

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

  attr_accessor :options, :clients

  def persistent_client_for(url, timeout: 600)
    uri = HTTP::URI.parse(url)
    clients[uri.origin] ||= HTTP.persistent(uri.origin, timeout: timeout)
  end

  def default_options
    {
      api_auth: options[:api_auth],
      keep_alive: options[:keep_alive],
      max_retries: options[:max_retries],
      on_complete: options[:on_complete],
      on_error: options[:on_error],
      retry_exceptions: options[:retry_exceptions],
      timeout: options[:default_timeout], # TODO: rename to timeout
    }
  end
end
