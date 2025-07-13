# frozen_string_literal: true

class EzClient::PersistentClientRegistry
  CLEANUP_INTERVAL = 60

  def self.build_for_client
    new
  end

  def initialize
    self.registry = {}
    self.cert_hash_cache = {}.compare_by_identity
    self.origin_cache = {}
    self.last_cleanup_at = nil
  end

  def for(url, ssl_context:, timeout:)
    cleanup_registry!

    origin = get_origin(url)
    ssl_bucket = ssl_context&.cert ? get_cached_cert_hash(ssl_context.cert) : nil

    registry_key = build_registry_key(origin, ssl_bucket)

    client = registry[registry_key]

    # If client exists but timed out, remove it and create a new one
    if client&.timed_out?
      registry.delete(registry_key)
      nil
    end

    registry[registry_key] ||= EzClient::PersistentClient.new(origin, timeout)
  end

  def truncate!
    registry.clear
    cert_hash_cache.clear
    origin_cache.clear
    self.last_cleanup_at = nil
  end

  private

  attr_accessor :registry, :cert_hash_cache, :origin_cache, :last_cleanup_at

  def get_cached_cert_hash(cert)
    cert_hash_cache[cert] ||= Digest::SHA256.hexdigest(cert.to_der).freeze
  end

  def build_registry_key(origin, ssl_bucket)
    ssl_bucket ? "#{origin}|#{ssl_bucket}".freeze : origin
  end

  def get_origin(url)
    origin_cache[url] ||= HTTP::URI.parse(url).origin
  end

  def cleanup_registry!
    current_time = EzClient.get_time
    return if last_cleanup_at && (current_time - last_cleanup_at) < CLEANUP_INTERVAL

    self.last_cleanup_at = current_time
    registry.delete_if { |_key, client| client.timed_out? }
  end
end
