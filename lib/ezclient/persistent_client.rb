# frozen_string_literal: true

class EzClient::PersistentClient
  extend Forwardable

  def_delegators :http_client, :build_request, :default_options, :timeout

  attr_accessor :origin, :keep_alive_timeout, :last_request_at

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

  private

  def http_client
    @http_client ||= HTTP.persistent(origin, timeout: keep_alive_timeout)
  end
end
