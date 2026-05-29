# frozen_string_literal: true

module ApiAuth
  def self.sign!(*); end
end

SomeError = Class.new(StandardError)

RSpec.describe EzClient do
  subject(:client) { described_class.new(client_options) }

  let(:client_options) { {} }
  let(:webmock_requests) { [] }

  let!(:request_stub) do
    stub_request(verb, %r{\Ahttp://example\.com})
      .with { |request| webmock_requests << request }
  end

  let(:verb) { :post }
  let(:request) { client.request(verb, "http://example.com", **request_options) }
  let(:request_options) { {} }

  context "when request is completed" do
    before { request_stub.to_return(webmock_response) }

    let(:webmock_response) { { body: "some body", headers: response_headers } }
    let(:request_options) { { form: { a: 1 }, metadata: :smth } }
    let(:response_headers) { { some: "header", set_cookie: "a=1" } }

    it "makes a request and returns a response" do
      response = request.perform

      expect(request.verb).to eq("POST")
      expect(request.url).to eq("http://example.com")
      expect(request.body).to eq("a=1")
      expect(request.elapsed_seconds).to be_a(Float)

      expect(request.headers).to eq(
        "Connection" => "close",
        "Content-Type" => "application/x-www-form-urlencoded",
        "Host" => "example.com",
        "User-Agent" => "ezclient/#{EzClient::VERSION}",
      )

      expect(response.body).to eq("some body")
      expect(response.headers).to eq("Some" => "header", "Set-Cookie" => "a=1")
      expect(response.cookies.to_a[0].to_s).to eq("a=1")
      expect(response.code).to eq(200)

      expect(webmock_requests.size).to eq(1)
    end

    context "when headers request option is provided" do
      let(:request_options) { { headers: headers } }
      let(:headers) { { some_header: 1 } }

      it "makes request with proper headers" do
        request.perform

        expect(webmock_requests.last.headers).to include(
          "Some-Header" => "1",
          "User-Agent" => "ezclient/#{EzClient::VERSION}",
        )
      end

      context "when user agent header is provided" do
        let(:headers) { { some_header: 1, user_agent: "UA" } }

        it "makes request with proper headers" do
          request.perform

          expect(webmock_requests.last.headers).to include(
            "Some-Header" => "1",
            "User-Agent" => "UA",
          )
        end
      end

      context "when cookies request option is provided" do
        let(:request_options) { { headers: headers, cookies: cookies } }
        let(:cookies) { { a: 1 } }

        it "makes request with proper headers" do
          request.perform

          expect(webmock_requests.last.headers).to include(
            "Some-Header" => "1",
            "User-Agent" => "ezclient/#{EzClient::VERSION}",
            "Cookie" => "a=1",
          )
        end
      end

      context "when add_headers! is used" do
        it "adds those headers" do
          request.add_headers!(new: "headers")
          request.perform

          expect(webmock_requests.last.headers).to include(
            "Some-Header" => "1",
            "New" => "headers",
          )
        end
      end
    end

    context "when query request option is provided" do
      let(:request_options) { { query: { a: 1 } } }

      it "makes proper request" do
        request.perform
        expect(webmock_requests.last.uri.query).to eq("a=1")
        expect(webmock_requests.last.body).to eq("")
      end
    end

    context "when body request option is provided" do
      let(:request_options) { { body: "some body" } }

      it "makes proper request" do
        request.perform
        expect(webmock_requests.last.body).to eq("some body")
      end
    end

    context "when json request option is provided" do
      let(:request_options) { { json: { a: 1 } } }

      it "makes proper request" do
        request.perform

        expect(webmock_requests.last.body).to eq('{"a":1}')
        expect(webmock_requests.last.headers["Content-Type"].downcase)
          .to eq("application/json; charset=utf-8")
      end
    end

    context "when params request option is provided" do
      let(:request_options) { { params: params } }
      let(:params) { { a: 1 } }

      it "makes proper request" do
        request.perform
        expect(webmock_requests.last.uri.query).to eq(nil)
        expect(webmock_requests.last.body).to eq("a=1")
      end

      context "GET request" do
        let(:verb) { :get }

        it "makes proper request" do
          request.perform
          expect(webmock_requests.last.uri.query).to eq("a=1")
          expect(webmock_requests.last.body).to eq("")
          expect(request.uri.to_s).to eq("http://example.com/?a=1")
        end
      end

      context "when request is using form and some param is File" do
        let(:params) { { a: File.new(Pathname.new(__dir__).join("files", "file.txt")) } }
        let(:body) { webmock_requests.last.body }

        it "makes proper request" do
          request.perform
          expect(body).to include('Content-Disposition: form-data; name="a"; filename="file.txt"')
          expect(body).to include("hello\nworld")
        end
      end
    end

    context "when calling perform on client" do
      it "performs a request" do
        response = client.perform(verb, "http://example.com", **request_options)
        expect(response.body).to eq("some body")
      end
    end

    context "when calling perform! on client" do
      it "performs a request" do
        response = client.perform!(verb, "http://example.com", **request_options)
        expect(response.body).to eq("some body")
      end
    end

    context "when on_complete callback is provided" do
      let(:client_options) { { on_complete: on_complete } }
      let(:calls) { [] }

      let(:on_complete) do
        proc do |request, response, metadata|
          expect(request.url).to eq("http://example.com")
          expect(response.body).to eq("some body")
          expect(metadata).to eq(:smth)
          calls << nil
        end
      end

      it "calls the on_error callback" do
        request.perform
        expect(calls.size).to eq(1)
      end
    end

    context "when 404 response is returned" do
      let(:webmock_response) { { status: 404, body: "Not Found" } }

      context "when calling perform on client" do
        it "performs a request" do
          response = client.perform(verb, "http://example.com", **request_options)
          expect(response.status).to eq(404)
        end
      end

      context "when calling perform! on client" do
        let(:perform_proc) do
          -> { client.perform!(verb, "http://example.com", **request_options) }
        end

        it "raises error" do
          expect(&perform_proc).to raise_exception do |exception|
            expect(exception).to be_a(EzClient::ResponseStatusError)
            expect(exception.response).to be_a(EzClient::Response)
            expect(exception.response.body).to eq("Not Found")
            expect(exception.response.code).to eq(404)
            expect(exception.message).to eq("Bad response code: 404")
          end
        end
      end
    end

    context "when keep_alive client option is provided" do
      let(:client_options) { { keep_alive: 10, timeout: 25 } }

      it "sends proper Connection header" do
        expect(request.headers).to include("Connection" => "Keep-Alive")
        expect(request.url).to eq("http://example.com")
        client.request(:get, "http://example2.com")
        response = request.perform!
        expect(response.body).to eq("some body")
      end

      context "when basic_auth and cookies are provided" do
        let(:request_options) { { basic_auth: %w[user password], cookies: { a: 1 } } }

        it "uses them while building a persistent request" do
          request.perform

          expect(webmock_requests.last.headers).to include(
            "Authorization" => "Basic dXNlcjpwYXNzd29yZA==",
            "Cookie" => "a=1",
          )
        end
      end
    end
  end

  context "when exception during request occurs" do
    before { request_stub.to_raise("Some error") }

    let(:request_options) { { metadata: :smth } }

    it "raises that error" do
      expect { request.perform }.to raise_error("Some error")
    end

    context "when on_error callback is provided" do
      let(:client_options) { { on_error: on_error } }
      let(:calls) { [] }

      let(:on_error) do
        proc do |request, error, metadata|
          expect(request.url).to eq("http://example.com")
          expect(request.elapsed_seconds).to be_a(Float)
          expect(error).to be_a(StandardError)
          expect(metadata).to eq(:smth)
          calls << nil
        end
      end

      it "calls the on_error callback" do
        expect { request.perform }.to raise_error("Some error")
        expect(calls.size).to eq(1)
      end
    end

    context "when error_wrapper callback is provided" do
      let(:client_options) { { error_wrapper: error_wrapper } }
      let(:calls) { [] }

      let(:error_wrapper) do
        proc do |request, error, _metadata|
          expect(request.url).to eq("http://example.com")
          expect(request.elapsed_seconds).to be_a(Float)
          expect(error).to be_a(StandardError)
          calls << nil
          raise "Wrapped some error"
        end
      end

      it "calls the error_wrapper callback" do
        expect { request.perform }.to raise_error("Wrapped some error")
        expect(calls.size).to eq(1)
      end
    end
  end

  context "when connection exception occurs" do
    before { request_stub.to_raise(HTTP::ConnectionError).to_return(body: "success") }

    it "retries request once" do
      response = request.perform
      expect(response.body).to eq("success")
    end

    context "when on_retry callback is provided" do
      let(:client_options) { { on_retry: on_retry } }
      let(:request_options) { { metadata: :smth } }
      let(:calls) { [] }

      let(:on_retry) do
        proc do |request, error, metadata|
          expect(request.url).to eq("http://example.com")
          expect(error).to be_a(HTTP::ConnectionError)
          expect(metadata).to eq(:smth)
          calls << nil
        end
      end

      it "calls the on_retry callback" do
        response = request.perform
        expect(calls.size).to eq(1)
        expect(response.body).to eq("success")
      end
    end
  end

  context "when timeout client option is provided" do
    let(:opts) { request.http_options }

    context "when timeout like integer" do
      let(:client_options) { { timeout: 10 } }
      let(:timeout) { 10.0 }

      it "uses it for request" do
        expect(opts.timeout_class).to eq(HTTP::Timeout::Global)
        expect(opts.timeout_options).to eq(global_timeout: timeout)
      end
    end

    context "when timeout like hash" do
      let(:client_options) { { timeout: { read: 5, write: 5, connect: 1 } } }
      let(:expected_configs) { { write_timeout: 5.0, read_timeout: 5.0, connect_timeout: 1.0 } }

      it "uses request option for request" do
        expect(opts.timeout_class).to eq(HTTP::Timeout::PerOperation)
        expect(opts.timeout_options).to eq(expected_configs)
      end
    end

    context "when timeout request option is provided as well" do
      let(:request_options) { { timeout: "15" } }
      let(:timeout) { 15.0 }

      it "uses request option for request" do
        expect(opts.timeout_class).to eq(HTTP::Timeout::Global)
        expect(opts.timeout_options).to eq(global_timeout: timeout)
      end
    end
  end

  context "when api_auth client option is provided" do
    let(:client_options) { { api_auth: %w[id secret] } }

    it "signs a request using ApiAuth lib" do
      expect(ApiAuth).to receive(:sign!) do |request, access_id, access_key|
        expect(request).to be_a(HTTP::Request)
        expect(access_id).to eq("id")
        expect(access_key).to eq("secret")
        request.headers.merge!("Authorization" => "some-hash-here")
      end

      expect(request.headers).to include("Authorization" => "some-hash-here")
    end

    context "when HTTP::Request does not expose header accessors" do
      let(:client_options) { {} }
      let(:http_request) { Struct.new(:headers).new(HTTP::Headers.new) }

      before do
        allow(http_request).to receive(:respond_to?).and_call_original
        allow(http_request).to receive(:respond_to?).with(:[]).and_return(false)
        allow(http_request).to receive(:respond_to?).with(:[]=).and_return(false)
        allow(request).to receive(:http_request).and_return(http_request)
      end

      it "adds api-auth-compatible header accessors" do
        expect(ApiAuth).to receive(:sign!) do |signed_request, access_id, access_key|
          expect(access_id).to eq("id")
          expect(access_key).to eq("secret")
          signed_request["Authorization"] = "some-hash-here"
        end

        request.api_auth!("id", "secret")

        expect(http_request.headers.to_h).to include("Authorization" => "some-hash-here")
      end
    end
  end

  context "when unknown client option is passed" do
    let(:client_options) { { foo: "smth", body: "smth", timeout: 5 } }

    it "raises error" do
      expect { client }.to raise_error(ArgumentError, "Unrecognized options: :foo, :body")
    end
  end

  context "when unknown request option is passed" do
    let(:request_options) { { foo: "smth", body: "smth", timeout: 5 } }

    it "raises error" do
      expect { request }.to raise_error(ArgumentError, "Unrecognized options: :foo")
    end
  end

  describe "response" do
    before { request_stub.to_return(webmock_response) }

    let(:response) { request.perform }
    let(:webmock_response) { { status: 201 } }

    context "object inspectation" do
      specify "#inspect" do
        inspected = response.inspect.gsub(/0x\w+/, "0x0000")
        # HTTP::Response#inspect format changed between httprb v5 and v6:
        # v5: "#<HTTP::Response/1.1 201 Created {}>"  (shows headers as {})
        # v6: "#<HTTP::Response/1.1 201 Created >"    (shows mime_type, nil = empty)
        expect(inspected).to include("#<EzClient::Response:0x0000")
        expect(inspected).to include("@http_response=#<HTTP::Response/1.1 201 Created")
        expect(inspected).to include("@http_request=#<HTTP::Request/1.1 POST http://example.com/>")
        expect(inspected).to include('@body="">')
      end

      specify "#to_s" do
        expect(response.inspect).to eq(response.to_s)
      end
    end

    context "201 response code" do
      specify do
        expect(response.code).to eq(201)
        expect(response.status).to eq(201)
        expect(response.ok?).to eq(true)
        expect(response.error?).to eq(false)
        expect(response.redirect?).to eq(false)
        expect(response.client_error?).to eq(false)
        expect(response.server_error?).to eq(false)
      end
    end

    context "302 response code" do
      let(:webmock_response) { { status: 302, headers: response_headers } }
      let(:response_headers) { {} }

      specify do
        expect(response.code).to eq(302)
        expect(response.status).to eq(302)
        expect(response.ok?).to eq(false)
        expect(response.error?).to eq(false)
        expect(response.redirect?).to eq(true)
        expect(response.client_error?).to eq(false)
        expect(response.server_error?).to eq(false)
      end

      context "when follow param presents" do
        let(:request_options) { { follow: true } }
        let(:verb) { :get }
        let(:response_headers) { { "Location" => "http://redirect.me" } }

        before do
          stub_request(:get, /redirect\.me/)
            .with { |request| webmock_requests << request }
        end

        it "follows the redirect" do
          request.perform
          expect(webmock_requests.size).to eq(2)
        end
      end
    end

    context "404 response code" do
      let(:webmock_response) { { status: 404 } }

      specify do
        expect(response.code).to eq(404)
        expect(response.status).to eq(404)
        expect(response.ok?).to eq(false)
        expect(response.error?).to eq(true)
        expect(response.redirect?).to eq(false)
        expect(response.client_error?).to eq(true)
        expect(response.server_error?).to eq(false)
      end
    end

    context "502 response code" do
      let(:webmock_response) { { status: 502 } }

      specify do
        expect(response.code).to eq(502)
        expect(response.status).to eq(502)
        expect(response.ok?).to eq(false)
        expect(response.error?).to eq(true)
        expect(response.redirect?).to eq(false)
        expect(response.client_error?).to eq(false)
        expect(response.server_error?).to eq(true)
      end
    end
  end

  context "when retry_exceptions request option is provided" do
    let(:request_options) { { retry_exceptions: [SomeError] } }

    context "server is responding with error" do
      before { request_stub.to_raise(SomeError) }

      it "raises exception after one retry" do
        expect { request.perform }.to raise_error(SomeError)
        expect(webmock_requests.size).to eq(2)
      end

      context "max_retries is 2" do
        let(:request_options) { { retry_exceptions: [SomeError], max_retries: 2 } }

        it "raises exception after 2 retries" do
          expect { request.perform }.to raise_error(SomeError)
          expect(webmock_requests.size).to eq(3)
        end
      end
    end

    context "server returns response after 1 retry" do
      before { request_stub.to_raise(SomeError).to_return(body: "success") }

      it "retries the response" do
        response = request.perform
        expect(response.body).to eq("success")
      end

      context "when on_retry callback is provided" do
        let(:client_options) { { on_retry: on_retry } }
        let(:request_options) { { retry_exceptions: SomeError, metadata: :smth } }
        let(:calls) { [] }

        let(:on_retry) do
          proc do |request, error, metadata|
            expect(request.url).to eq("http://example.com")
            expect(error).to be_a(SomeError)
            expect(metadata).to eq(:smth)
            calls << nil
          end
        end

        it "calls the on_retry callback" do
          response = request.perform
          expect(calls.size).to eq(1)
          expect(response.body).to eq("success")
        end
      end
    end
  end

  context "when basic_auth request option is provided as hash" do
    let(:request_options) { { basic_auth: { user: "user", pass: "password" } } }

    it "adds Authorization header" do
      expect(request.headers).to include("Authorization" => "Basic dXNlcjpwYXNzd29yZA==")
    end
  end

  context "when basic_auth request option is provided as array" do
    let(:request_options) { { basic_auth: %w[user password] } }

    it "adds Authorization header" do
      expect(request.headers).to include("Authorization" => "Basic dXNlcjpwYXNzd29yZA==")
    end
  end

  # The following contexts exercise httprb v6-specific code paths by stubbing
  # HTTP::Client#build_request as unsupported, ensuring coverage even when running under httprb v5.
  context "when HTTP::Client#build_request is unsupported" do
    before do
      allow(EzClient::HttprbCompatibility)
        .to receive(:client_supports_build_request?)
        .and_return(false)

      unless defined?(HTTP::Request::Builder)
        stub_const("HTTP::Request::Builder", Class.new do
          def initialize(opts)
            @opts = opts
          end

          def build(verb, url)
            HTTP::Client.new.build_request(verb, url, @opts)
          end
        end)
      end
    end

    context "when making a basic request" do
      before { request_stub.to_return(body: "v6 response") }

      it "performs request using HTTP::Request::Builder" do
        response = request.perform
        expect(response.body).to eq("v6 response")
      end
    end

    context "when basic_auth request option is provided" do
      let(:request_options) { { basic_auth: { user: "user", pass: "password" } } }

      it "sets Authorization header using keyword args (v6 path)" do
        expect(request.headers).to include("Authorization" => "Basic dXNlcjpwYXNzd29yZA==")
      end
    end

    context "when follow redirect" do
      before do
        request_stub.to_return(status: 302, headers: { "Location" => "http://redirect.me" })
      end

      let(:verb) { :get }
      let(:request_options) { { follow: true } }

      before do
        stub_request(:get, /redirect\.me/)
          .with { |req| webmock_requests << req }
          .to_return(body: "redirected")
      end

      it "follows redirect using HTTP::Redirector with keyword args" do
        request.perform
        expect(webmock_requests.size).to eq(2)
      end
    end

    context "when followed redirect sets cookies" do
      before do
        request_stub.to_return(
          status: 302,
          headers: { "Location" => "http://example.com/redirected", "Set-Cookie" => "sid=1" },
        )

        stub_request(:get, "http://example.com/redirected")
          .with { |req| webmock_requests << req }
          .to_return(body: "redirected")
      end

      let(:verb) { :get }
      let(:request_options) { { follow: true } }

      it "sends response cookies to the next request" do
        request.perform
        expect(webmock_requests.last.headers).to include("Cookie" => "sid=1")
      end
    end

    context "when follow redirect has on_redirect callback" do
      let(:verb) { :get }
      let(:calls) { [] }
      let(:request_options) { { follow: { on_redirect: on_redirect } } }

      let(:on_redirect) do
        proc do |response, redirect_request|
          calls << [response.code, redirect_request.headers[HTTP::Headers::COOKIE].to_s]
        end
      end

      before do
        request_stub.to_return(
          status: 302,
          headers: { "Location" => "http://example.com/redirected", "Set-Cookie" => "sid=1" },
        )

        stub_request(:get, "http://example.com/redirected")
          .with { |req| webmock_requests << req }
          .to_return(body: "redirected")
      end

      it "calls it with the response and redirected request after applying cookies" do
        request.perform
        expect(calls).to eq([[302, "sid=1"]])
      end
    end

    context "when redirected request has cookies" do
      before do
        request_stub.to_return(
          status: 302,
          headers: { "Location" => "http://example.com/redirected" },
        )

        stub_request(:get, "http://example.com/redirected")
          .with { |req| webmock_requests << req }
          .to_return(body: "redirected")
      end

      let(:verb) { :get }
      let(:request_options) { { cookies: { sid: 1 }, follow: true } }

      it "sends original request cookies to the next request" do
        request.perform
        expect(webmock_requests.last.headers).to include("Cookie" => "sid=1")
      end
    end

    context "when redirect response sets an empty cookie" do
      before do
        request_stub.to_return(
          status: 302,
          headers: {
            "Location" => "http://example.com/redirected",
            "Set-Cookie" => "sid=; Path=/",
          },
        )

        stub_request(:get, "http://example.com/redirected")
          .with { |req| webmock_requests << req }
          .to_return(body: "redirected")
      end

      let(:verb) { :get }
      let(:request_options) { { follow: true } }

      it "preserves it as a legitimate cookie value" do
        request.perform
        expect(webmock_requests.last.headers).to include("Cookie" => "sid=")
      end
    end

    context "when redirect response expires cookies" do
      before do
        request_stub.to_return(
          status: 302,
          headers: {
            "Location" => "http://example.com/redirected",
            "Set-Cookie" => "sid=; Max-Age=0; Path=/",
          },
        )

        stub_request(:get, "http://example.com/redirected")
          .with { |req| webmock_requests << req }
          .to_return(body: "redirected")
      end

      let(:verb) { :get }
      let(:request_options) { { cookies: { sid: 1 }, follow: true } }

      it "removes expired cookies from the next request" do
        request.perform
        expect(webmock_requests.last.headers).not_to include("Cookie")
      end
    end
  end
end

RSpec.describe EzClient::Request::RedirectCookieState do
  let(:cookies) { { sid: "a;b" } }

  let(:ezclient_request) do
    EzClient.new.request(:get, "http://example.com", cookies: cookies)
  end

  let(:http_request) { ezclient_request.send(:http_request) }
  let(:redirect_request) { http_request.redirect("http://example.com/redirected") }
  let(:response) { Struct.new(:headers, :request).new(HTTP::Headers.coerce({}), http_request) }

  it "preserves request cookie values that require quoting" do
    described_class.new(response).apply_to(redirect_request)

    expect(redirect_request.headers[HTTP::Headers::COOKIE].to_s).to eq('sid="a;b"')
  end

  context "when request has a full Cookie header string" do
    let(:cookies) { {} }

    before do
      http_request.headers[HTTP::Headers::COOKIE] = 'sid="a;b"; path=/'
    end

    it "round-trips every parsed cookie pair to the redirect request" do
      described_class.new(response).apply_to(redirect_request)

      expect(redirect_request.headers[HTTP::Headers::COOKIE].to_s).to eq('sid="a;b"; path=/')
    end
  end
end

RSpec.describe EzClient::HttprbCompatibility do
  context "when basic auth expects keyword arguments" do
    let(:client_class) do
      Class.new do
        attr_reader :credentials

        def basic_auth(user:, pass:)
          @credentials = { user: user, pass: pass }
          self
        end
      end
    end

    let(:client) { client_class.new }

    it "passes credentials as keyword arguments" do
      expect(described_class.basic_auth(client, { user: "user", pass: "password" })).to eq(client)
      expect(client.credentials).to eq(user: "user", pass: "password")
    end
  end

  context "when redirector expects keyword arguments" do
    let(:redirector_class) do
      Class.new do
        attr_reader :options

        def initialize(max_hops:)
          @options = { max_hops: max_hops }
        end
      end
    end

    before do
      stub_const("HTTP::Redirector", redirector_class)
    end

    it "passes options as keyword arguments" do
      expect(described_class.redirector(max_hops: 3).options).to eq(max_hops: 3)
    end
  end

  context "when response expects keyword arguments" do
    let(:response_class) do
      Class.new do
        attr_reader :attributes

        def initialize(status:, headers:)
          @attributes = { status: status, headers: headers }
        end
      end
    end

    before do
      stub_const("HTTP::Response", response_class)
    end

    it "passes attributes as keyword arguments" do
      expect(described_class.response(status: 200, headers: {}).attributes)
        .to eq(status: 200, headers: {})
    end
  end

  context "when response expects positional hash" do
    let(:response_class) do
      Class.new do
        attr_reader :attributes

        def initialize(attributes)
          @attributes = attributes
        end
      end
    end

    before do
      stub_const("HTTP::Response", response_class)
    end

    it "passes attributes as a positional hash" do
      expect(described_class.response(status: 200, headers: {}).attributes)
        .to eq(status: 200, headers: {})
    end
  end
end

RSpec.describe EzClient::PersistentClient do
  # Exercises the httprb v6-specific code path in http_client by stubbing
  # build_request as unsupported.
  context "when HTTP::Client#build_request is unsupported" do
    before do
      allow(EzClient::HttprbCompatibility)
        .to receive(:client_supports_build_request?)
        .and_return(false)
    end

    it "creates HTTP::Client with persistent connection options" do
      mock_client = double("HTTP::Client")
      allow(HTTP::Client).to receive(:new)
        .with(persistent: "http://example.com", keep_alive_timeout: 5)
        .and_return(mock_client)

      client = EzClient::PersistentClient.new("http://example.com", 5)
      client.send(:http_client)

      expect(HTTP::Client).to have_received(:new)
        .with(persistent: "http://example.com", keep_alive_timeout: 5)
    end
  end
end
