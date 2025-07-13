# frozen_string_literal: true

class EzClient::PersistentClientRegistry
  DEFAULT_CLEANUP_INTERVAL = 60

  def self.build_for_client(cleanup_interval: nil)
    new(cleanup_interval: cleanup_interval || DEFAULT_CLEANUP_INTERVAL)
  end

  def initialize(cleanup_interval: DEFAULT_CLEANUP_INTERVAL)
    self.registry = {}
    self.cert_hash_cache = {}.compare_by_identity
    self.origin_cache = {}
    self.last_cleanup_at = nil
    self.cleanup_interval = cleanup_interval
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

  attr_accessor :registry, :cert_hash_cache, :origin_cache, :last_cleanup_at, :cleanup_interval

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
    return if last_cleanup_at && (current_time - last_cleanup_at) < cleanup_interval

    self.last_cleanup_at = current_time
    registry.delete_if { |_key, client| client.timed_out? }
  end
end
