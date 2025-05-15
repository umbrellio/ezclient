# frozen_string_literal: true

RSpec.describe "Persistent Connections" do
  around do |example|
    WebMock.disable!
    example.run
  ensure
    WebMock.enable!
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

  it "removes connections that are timed out on each request" do
    client = EzClient.new(keep_alive: 1, timeout: 15)

    2.times do
      client.perform!(:get, "https://ya.ru")
      client.perform!(:get, "https://google.com")
      client.perform!(:get, "https://example.com")
      sleep 0.6
    end

    sleep 0.6

    client.perform!(:get, "https://example.com")

    GC.start

    connection_count = ObjectSpace.each_object(HTTP::Connection).count
    expect(connection_count).to eq(1)
  end

  it "boots up separate http connections for different ssl contexts" do
    client = EzClient.new(keep_alive: 1)

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
