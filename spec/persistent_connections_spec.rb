# frozen_string_literal: true

RSpec.describe "Persistent Connections" do
  around do |example|
    WebMock.disable!
    example.run
  ensure
    WebMock.enable!
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
end
