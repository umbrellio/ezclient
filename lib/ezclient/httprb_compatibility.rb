# frozen_string_literal: true

module EzClient::HttprbCompatibility
  KEYWORD_PARAMETER_TYPES = %i[key keyreq].freeze

  module_function

  def client_supports_build_request?
    HTTP::Client.method_defined?(:build_request)
  end

  def httprb_v6_or_later?
    Gem::Version.new(HTTP::VERSION) >= Gem::Version.new("6")
  end

  def build_request(client, verb, url, opts)
    if client_supports_build_request?
      client.build_request(verb, url, opts)
    else
      HTTP::Request::Builder.new(client.default_options.merge(opts)).build(verb, url)
    end
  end

  def basic_auth(client, opts)
    if keyword_initializer?(client.method(:basic_auth))
      client.basic_auth(**opts)
    else
      client.basic_auth(opts)
    end
  end

  def redirector(opts)
    if keyword_initializer?(HTTP::Redirector.instance_method(:initialize))
      HTTP::Redirector.new(**opts)
    else
      HTTP::Redirector.new(opts)
    end
  end

  def persistent_client(origin, keep_alive_timeout)
    if client_supports_build_request?
      HTTP.persistent(origin, timeout: keep_alive_timeout)
    else
      HTTP::Client.new(persistent: origin, keep_alive_timeout: keep_alive_timeout)
    end
  end

  def response(**attrs)
    if keyword_initializer?(HTTP::Response.instance_method(:initialize))
      HTTP::Response.new(**attrs)
    else
      HTTP::Response.new(attrs)
    end
  end

  def keyword_initializer?(method)
    method.parameters.any? { |type, _name| KEYWORD_PARAMETER_TYPES.include?(type) }
  end
end
