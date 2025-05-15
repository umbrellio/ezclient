# frozen_string_literal: true

class EzClient::PersistentClientRegistry
  def initialize
    self.registry = {}
  end

  def for(url, ssl_context:, timeout:)
    cleanup_registry!

    origin = get_origin(url)
    registry[origin] ||= {}

    ssl_bucket = ssl_context ? get_cert_sha256(ssl_context.cert) : nil
    registry[origin][ssl_bucket] ||= EzClient::PersistentClient.new(origin, timeout)
  end

  private

  attr_accessor :registry

  def get_cert_sha256(cert)
    Digest::SHA256.hexdigest(cert.to_der)
  end

  def get_origin(url)
    HTTP::URI.parse(url).origin
  end

  def cleanup_registry!
    registry.each_value do |ssl_buckets|
      ssl_buckets.delete_if { |_ssl_bucket, client| client.timed_out? }
    end
  end
end
