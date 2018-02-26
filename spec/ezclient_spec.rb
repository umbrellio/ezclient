# frozen_string_literal: true

module ApiAuth
  def self.sign!(*); end
end

SomeError = Class.new(StandardError)

RSpec.describe EzClient do
  subject(:client) { described_class.new(client_options) }

  let(:client_options) { Hash[] }
  let(:wembock_requests) { [] }

  let!(:request_stub) do
    stub_request(verb, %r{\Ahttp://example\.com})
      .with { |request| wembock_requests << request }
  end

  let(:verb) { :post }
  let(:request) { client.request(verb, "http://example.com", **request_options) }
  let(:request_options) { Hash[] }

  context "when request is completed" do
    before { request_stub.to_return(webmock_response) }

    let(:webmock_response) { Hash[body: "some body", headers: { some: "header" }] }
    let(:request_options) { Hash[form: Hash[a: 1], metadata: :smth] }

    it "makes a request and returns a response" do
      response = request.perform

      expect(request.verb).to eq("POST")
      expect(request.url).to eq("http://example.com")
      expect(request.body).to eq("a=1")

      expect(request.headers).to include(
        "Connection" => "close",
        "Content-Type" => "application/x-www-form-urlencoded",
        "Host" => "example.com",
      )

      expect(response.body).to eq("some body")
      expect(response.headers).to eq("Some" => "header")
      expect(response.code).to eq(200)

      expect(wembock_requests.size).to eq(1)
    end

    context "when query request option is provided" do
      let(:request_options) { Hash[query: Hash[a: 1]] }

      it "makes proper request" do
        request.perform
        expect(wembock_requests.last.uri.query).to eq("a=1")
        expect(wembock_requests.last.body).to eq("")
      end
    end

    context "when body request option is provided" do
      let(:request_options) { Hash[body: "some body"] }

      it "makes proper request" do
        request.perform
        expect(wembock_requests.last.body).to eq("some body")
      end
    end

    context "when json request option is provided" do
      let(:request_options) { Hash[json: Hash[a: 1]] }

      it "makes proper request" do
        request.perform

        expect(wembock_requests.last.body).to eq('{"a":1}')
        expect(wembock_requests.last.headers).to include(
          "Content-Type" => "application/json; charset=UTF-8",
        )
      end
    end

    context "when params request option is provided" do
      let(:request_options) { Hash[params: Hash[a: 1]] }

      it "makes proper request" do
        request.perform
        expect(wembock_requests.last.uri.query).to eq(nil)
        expect(wembock_requests.last.body).to eq("a=1")
      end

      context "GET request" do
        let(:verb) { :get }

        it "makes proper request" do
          request.perform
          expect(wembock_requests.last.uri.query).to eq("a=1")
          expect(wembock_requests.last.body).to eq("")
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
      let(:client_options) { Hash[on_complete: on_complete] }
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
      let(:webmock_response) { Hash[status: 404, body: "Not Found"] }

      context "when calling perform on client" do
        it "performs a request" do
          response = client.perform(verb, "http://example.com", **request_options)
          expect(response.status).to eq(404)
        end
      end

      context "when calling perform! on client" do
        let(:perform_args) { [verb, "http://example.com", **request_options] }

        it "raises error" do
          expect { client.perform!(*perform_args) }.to raise_exception do |exception|
            expect(exception).to be_a(EzClient::ResponseStatusError)
            expect(exception.response).to be_a(EzClient::Response)
            expect(exception.response.body).to eq("Not Found")
            expect(exception.response.code).to eq(404)
            expect(exception.message).to eq("Bad response code: 404")
          end
        end
      end
    end
  end

  context "when exception during request occurs" do
    before { request_stub.to_raise("Some error") }

    let(:request_options) { Hash[metadata: :smth] }

    it "raises that error" do
      expect { request.perform }.to raise_error("Some error")
    end

    context "when on_error callback is provided" do
      let(:client_options) { Hash[on_error: on_error] }
      let(:calls) { [] }

      let(:on_error) do
        proc do |request, error, metadata|
          expect(request.url).to eq("http://example.com")
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
  end

  context "when connection exception occurs" do
    before { request_stub.to_raise(HTTP::ConnectionError).to_return(body: "success") }

    it "retries request once" do
      response = request.perform
      expect(response.body).to eq("success")
    end

    context "when on_retry callback is provided" do
      let(:client_options) { Hash[on_retry: on_retry] }
      let(:request_options) { Hash[metadata: :smth] }
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

  context "when keep_alive client option is provided" do
    let(:client_options) { Hash[keep_alive: 10] }

    it "sends proper Connection header" do
      expect(request.headers).to include("Connection" => "Keep-Alive")
    end
  end

  context "when timeout client option is provided" do
    let(:client_options) { Hash[timeout: 10] }
    let(:opts) { request.http_options }

    it "uses it for request" do
      expect(opts.timeout_class).to eq(HTTP::Timeout::Global)
      expect(opts.timeout_options).to eq(global_timeout: 10)
    end

    context "when timeout request option is provided as well" do
      let(:request_options) { Hash[timeout: "15"] }

      it "uses request option for request" do
        expect(opts.timeout_class).to eq(HTTP::Timeout::Global)
        expect(opts.timeout_options).to eq(global_timeout: 15)
      end
    end
  end

  context "when api_auth client option is provided" do
    let(:client_options) { Hash[api_auth: %w[id secret]] }

    it "signs a request using ApiAuth lib" do
      expect(ApiAuth).to receive(:sign!) do |request, access_id, access_key|
        expect(request).to be_a(HTTP::Request)
        expect(access_id).to eq("id")
        expect(access_key).to eq("secret")
      end

      request
    end
  end

  context "when unknown client option is passed" do
    let(:client_options) { Hash[foo: "smth", body: "smth", timeout: 5] }

    it "raises error" do
      expect { client }.to raise_error(ArgumentError, "Unrecognized options: :foo, :body")
    end
  end

  context "when unknown request option is passed" do
    let(:request_options) { Hash[foo: "smth", body: "smth", timeout: 5] }

    it "raises error" do
      expect { request }.to raise_error(ArgumentError, "Unrecognized options: :foo")
    end
  end

  describe "response" do
    before { request_stub.to_return(webmock_response) }

    let(:response) { request.perform }
    let(:webmock_response) { Hash[status: 201] }

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
      let(:webmock_response) { Hash[status: 302] }

      specify do
        expect(response.code).to eq(302)
        expect(response.status).to eq(302)
        expect(response.ok?).to eq(false)
        expect(response.error?).to eq(false)
        expect(response.redirect?).to eq(true)
        expect(response.client_error?).to eq(false)
        expect(response.server_error?).to eq(false)
      end
    end

    context "404 response code" do
      let(:webmock_response) { Hash[status: 404] }

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
      let(:webmock_response) { Hash[status: 502] }

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
    let(:request_options) { Hash[retry_exceptions: [SomeError]] }

    context "server is responding with error" do
      before { request_stub.to_raise(SomeError) }

      it "raises exception after one retry" do
        expect { request.perform }.to raise_error(SomeError)
        expect(wembock_requests.size).to eq(2)
      end

      context "max_retries is 2" do
        let(:request_options) { Hash[retry_exceptions: [SomeError], max_retries: 2] }

        it "raises exception after 2 retries" do
          expect { request.perform }.to raise_error(SomeError)
          expect(wembock_requests.size).to eq(3)
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
        let(:client_options) { Hash[on_retry: on_retry] }
        let(:request_options) { Hash[retry_exceptions: SomeError, metadata: :smth] }
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
    let(:request_options) { Hash[basic_auth: Hash[user: "user", pass: "password"]] }

    it "adds Authorization header" do
      expect(request.headers).to include("Authorization" => "Basic dXNlcjpwYXNzd29yZA==")
    end
  end

  context "when basic_auth request option is provided as array" do
    let(:request_options) { Hash[basic_auth: %w[user password]] }

    it "adds Authorization header" do
      expect(request.headers).to include("Authorization" => "Basic dXNlcjpwYXNzd29yZA==")
    end
  end
end
