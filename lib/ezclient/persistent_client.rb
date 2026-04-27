# frozen_string_literal: true

class EzClient::PersistentClient
  extend Forwardable

  def_delegators :http_client, :build_request, :default_options, :timeout

  def initialize(origin, keep_alive_timeout)
    self.origin = origin
    self.keep_alive_timeout = keep_alive_timeout
    self.last_request_at = nil
  end

  def perform(*args)
    http_client.perform(*args).tap do
      self.last_request_at = EzClient.get_time
    end
  end

  def timed_out?
    last_request_at && EzClient.get_time - last_request_at >= keep_alive_timeout
  end

  private

  attr_accessor :origin, :keep_alive_timeout, :last_request_at

  def http_client
    @http_client ||=
      if EzClient::HTTP_GEM_V6
        # NOTE: In v6, HTTP.persistent returns HTTP::Session (no #perform(req, opts)).
        # NOTE: Instead, create an HTTP::Client directly with persistent connection options.
        HTTP::Client.new(persistent: origin, keep_alive_timeout: keep_alive_timeout)
      else
        # NOTE: In v4/v5, HTTP.persistent returns HTTP::Client directly.
        HTTP.persistent(origin, timeout: keep_alive_timeout)
      end
  end
end
