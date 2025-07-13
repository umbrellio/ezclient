# frozen_string_literal: true

RSpec.describe "Persistent Connections" do
  let(:current_time_shift) { 0.5 }
  let(:current_time) { 0 }

  around do |example|
    WebMock.disable!
    example.run
  ensure
    WebMock.enable!
  end

  before do
    time = current_time
    allow(EzClient).to receive(:get_time) do
      result = time
      time += current_time_shift
      result
    end
  end

  def read_file(path)
    File.new("#{__dir__}/files/#{path}").read
  end

  def make_ssl_context(cert, key)
    OpenSSL::SSL::SSLContext.new.tap do |ssl_context|
      ssl_context.cert = OpenSSL::X509::Certificate.new(cert)
      ssl_context.key = OpenSSL::PKey.read(key)
    end
  end

  context "when connections timeout" do
    let(:current_time_shift) { 2 }

    it "removes connections that are timed out on each request" do
      stub_const("EzClient::PersistentClientRegistry::CLEANUP_INTERVAL", 5)

      client = EzClient.new(keep_alive: 1, timeout: 15)

      client.perform!(:get, "https://ya.ru")
      client.perform!(:get, "https://google.com")
      client.perform!(:get, "https://example.com")

      client.perform!(:get, "https://example.com")

      GC.start

      connection_count = ObjectSpace.each_object(HTTP::Connection).count
      expect(connection_count).to eq(1)
    end
  end

  context "with SSL contexts" do
    it "boots up separate http connections for different ssl contexts" do
      client = EzClient.new(keep_alive: 15)

      cert1 = read_file("cert1/cert.pem")
      key1 = read_file("cert1/key.pem")
      cert2 = read_file("cert2/cert.pem")
      key2 = read_file("cert2/key.pem")

      ssl_context1 = make_ssl_context(cert1, key1)
      ssl_context2 = make_ssl_context(cert2, key2)

      2.times do
        client.perform!(:get, "https://ya.ru", ssl_context: ssl_context1)
      end

      2.times do
        client.perform!(:get, "https://ya.ru", ssl_context: ssl_context2)
      end

      GC.start

      connection_count = ObjectSpace.each_object(HTTP::Connection).count
      expect(connection_count).to eq(2)
    end
  end

  context "with caching optimizations" do
    before do
      allow(EzClient::PersistentClientRegistry).to receive(:build_for_client).and_return(registry)
    end

    let(:current_time_shift) { 0 }
    let(:client) { EzClient.new(keep_alive: 10) }
    let(:registry) { EzClient::PersistentClientRegistry.new }

    context "with SHA256 certificate hash caching" do
      it "caches certificate hashes to avoid recomputation" do
        cert = OpenSSL::X509::Certificate.new(read_file("cert1/cert.pem"))

        expect(Digest::SHA256).to receive(:hexdigest).once.and_call_original

        hash1 = registry.send(:get_cached_cert_hash, cert)
        hash2 = registry.send(:get_cached_cert_hash, cert)

        expect(hash1).to eq(hash2)
      end
    end

    context "with URL origin caching" do
      it "caches parsed URL origins" do
        url = "https://example.com/path?query=1"

        expect(HTTP::URI).to receive(:parse).once.and_call_original

        origin1 = registry.send(:get_origin, url)
        origin2 = registry.send(:get_origin, url)

        expect(origin1).to eq(origin2)
        expect(origin1).to eq("https://example.com")
      end
    end

    context "with cleanup interval optimization" do
      it "skips cleanup if called within CLEANUP_INTERVAL" do
        stub_const("EzClient::PersistentClientRegistry::CLEANUP_INTERVAL", 10)

        registry.send(:cleanup_registry!)

        expect(registry.send(:registry)).not_to receive(:delete_if)
        registry.send(:cleanup_registry!)
      end

      it "performs cleanup after CLEANUP_INTERVAL has passed" do
        stub_const("EzClient::PersistentClientRegistry::CLEANUP_INTERVAL", 10)

        current_time = 0
        allow(EzClient).to receive(:get_time) { current_time }

        registry.send(:cleanup_registry!)

        current_time = 15

        expect(registry.send(:registry)).to receive(:delete_if).and_call_original
        registry.send(:cleanup_registry!)
      end
    end

    context "when client times out before cleanup" do
      around do |example|
        WebMock.enable!
        example.run
      ensure
        WebMock.disable!
      end

      before { stub_request(:get, "https://example.com").to_return(status: 200, body: "OK") }

      let(:registry) { EzClient::PersistentClientRegistry.new }

      it "removes timed out client on next access" do
        client1 = registry.for("https://example.com", ssl_context: nil, timeout: 5)
        request = HTTP::Request.new(verb: :get, uri: "https://example.com")
        client1.perform(request, HTTP::Options.new)
        expect(registry.send(:registry).size).to eq(1)

        allow(EzClient).to receive(:get_time).and_return(10)

        client2 = registry.for("https://example.com", ssl_context: nil, timeout: 5)

        expect(client2).not_to eq(client1)
        expect(client1.timed_out?).to be true
        expect(registry.send(:registry).size).to eq(1)
      end

      context "with multiple timed out clients" do
        before do
          stub_request(:get, "https://example1.com").to_return(status: 200, body: "OK")
          stub_request(:get, "https://example2.com").to_return(status: 200, body: "OK")
        end

        it "handles correctly" do
          client1 = registry.for("https://example1.com", ssl_context: nil, timeout: 5)
          client2 = registry.for("https://example2.com", ssl_context: nil, timeout: 5)

          request1 = HTTP::Request.new(verb: :get, uri: "https://example1.com")
          request2 = HTTP::Request.new(verb: :get, uri: "https://example2.com")

          client1.perform(request1, HTTP::Options.new)
          client2.perform(request2, HTTP::Options.new)

          expect(registry.send(:registry).size).to eq(2)

          allow(EzClient).to receive(:get_time).and_return(10)

          new_client1 = registry.for("https://example1.com", ssl_context: nil, timeout: 5)

          expect(new_client1).not_to eq(client1)
          expect(registry.send(:registry).size).to eq(2)

          new_client2 = registry.for("https://example2.com", ssl_context: nil, timeout: 5)

          expect(new_client2).not_to eq(client2)
          expect(registry.send(:registry).size).to eq(2)
        end
      end
    end

  end
end
