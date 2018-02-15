# frozen_string_literal: true

module ApiAuth
  def self.sign!(*); end
end

RSpec.describe EzClient do
  subject(:client) { described_class.new(options) }

  let(:options) { Hash[] }
  let(:wembock_requests) { [] }

  let!(:request_stub) do
    stub_request(:post, "http://example.com")
      .with { |request| wembock_requests << request }
  end

  let(:request) { client.request(:post, "http://example.com", **request_options) }
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

    context "on_complete callback provided" do
      let(:options) { Hash[on_complete: on_complete] }
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
  end

  context "when exception during request occurs" do
    before { request_stub.to_raise("Some error") }

    let(:request_options) { Hash[metadata: :smth] }

    it "raises that error" do
      expect { request.perform }.to raise_error("Some error")
    end

    context "when on_error callback is provided" do
      let(:options) { Hash[on_error: on_error] }
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

  context "when keep_alive option is provided" do
    it "sends proper Connection header" do
      request = client.request(:post, "http://example.com", keep_alive: 10)
      expect(request.headers).to include("Connection" => "Keep-Alive")
    end
  end

  describe "#api_auth!" do
    it "signs a request using ApiAuth lib" do
      expect(ApiAuth).to receive(:sign!) do |request, access_id, access_key|
        expect(request).to be_a(HTTP::Request)
        expect(access_id).to eq("id")
        expect(access_key).to eq("secret")
      end

      request.api_auth!("id", "secret")
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
end
