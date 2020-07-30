# frozen_string_literal: true

class EzClient::PersistentClientRegistry
  def initialize
    self.registry = {}
  end

  def for(url, timeout:)
    uri = HTTP::URI.parse(url)
    cleanup_registry!
    registry[uri.origin] ||= EzClient::PersistentClient.new(uri.origin, timeout)
  end

  private

  attr_accessor :registry

  def cleanup_registry!
    registry.delete_if do |_key, value|
      EzClient.get_time - value.last_request_at >= value.keep_alive_timeout
    end
  end
end
