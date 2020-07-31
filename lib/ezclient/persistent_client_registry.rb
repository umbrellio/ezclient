# frozen_string_literal: true

class EzClient::PersistentClientRegistry
  def initialize
    self.registry = {}
  end

  def for(url, timeout:)
    cleanup_registry!
    uri = HTTP::URI.parse(url)
    registry[uri.origin] ||= EzClient::PersistentClient.new(uri.origin, timeout)
  end

  private

  attr_accessor :registry

  def cleanup_registry!
    registry.delete_if { |_origin, client| client.timed_out? }
  end
end
