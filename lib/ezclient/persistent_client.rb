# frozen_string_literal: true

class EzClient::PersistentClient
  extend Forwardable

  def initialize(origin, timeout)
    self.origin = origin
    self.timeout = timeout
  end

  def_delegators :http_client, :build_request, :default_options, :perform

  private

  attr_accessor :origin, :timeout

  def http_client
    @http_client ||= HTTP.persistent(origin, timeout: timeout)
  end
end
