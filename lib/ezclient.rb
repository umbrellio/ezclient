# frozen_string_literal: true

require "http"
require "ezclient/version"
require "ezclient/request"
require "ezclient/response"

class EzClient
  def initialize(options = {})
    self.options = options
    self.clients = {}
  end

  def request(verb, url, **options)
    keep_alive_timeout = options.delete(:keep_alive)

    if keep_alive_timeout
      client = persistent_client_for(url, timeout: keep_alive_timeout)
    else
      client = HTTP::Client.new
    end

    Request.new(verb, url, client: client, **default_options, **options)
  end

  private

  attr_accessor :options, :clients

  def persistent_client_for(url, timeout: 600)
    uri = HTTP::URI.parse(url)
    clients[uri.origin] ||= HTTP.persistent(uri.origin, timeout: timeout)
  end

  def default_options()
    {
      on_complete: options[:on_complete],
      on_error: options[:on_error],
      timeout: options[:default_timeout],
    }
  end
end
