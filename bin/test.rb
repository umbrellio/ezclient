gem "httplog"

require_relative "../lib/ezclient"

require "httplog"
require "json"

HttpLog.config.logger = Logger.new(STDOUT)
HttpLog.config.log_response = false

client = EzClient.new(keep_alive: 1)

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

unless connection_count == 1
  abort "Number of connections: #{connection_count}"
end
