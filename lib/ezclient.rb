# frozen_string_literal: true

require "http"
require "ezclient/version"
require "ezclient/request"
require "ezclient/response"

class EzClient
  def initialize(on_complete: nil, on_error: nil)
    self.clients = {}
    self.on_complete = on_complete
    self.on_error = on_error
  end

  def request(verb, url, **options)
    keep_alive_timeout = options.delete(:keep_alive)

    if keep_alive_timeout
      client = persistent_client_for(url, timeout: keep_alive_timeout)
    else
      client = HTTP::Client.new
    end

    Request.new(verb, url, client: client, on_complete: on_complete, on_error: on_error, **options)
  end

  private

  attr_accessor :clients, :on_complete, :on_error

  def persistent_client_for(url, timeout: 600)
    uri = HTTP::URI.parse(url)
    clients[uri.origin] ||= HTTP.persistent(uri.origin, timeout: timeout)
  end
end
