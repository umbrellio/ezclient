# frozen_string_literal: true

unless HTTP::Client.instance_methods.include?(:build_request)
  # Backport of https://github.com/httprb/http/pull/458 for HTTP v3
  class HTTP::Client
    def build_request(verb, uri, opts = {})
      opts    = @default_options.merge(opts)
      uri     = make_request_uri(uri, opts)
      headers = make_request_headers(opts)
      body    = make_request_body(opts, headers)
      proxy   = opts.proxy

      HTTP::Request.new(
        verb: verb,
        uri: uri,
        headers: headers,
        proxy: proxy,
        body: body,
        auto_deflate: opts.feature(:auto_deflate)
      )
    end
  end
end

unless HTTP::Request::Body.instance_methods.include?(:source)
  # Backport for HTTP v3
  class HTTP::Request::Body
    def source
      @body
    end
  end
end
