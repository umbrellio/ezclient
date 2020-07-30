# frozen_string_literal: true

require "http"
require "ezclient/version"
require "ezclient/client"
require "ezclient/persistent_client"
require "ezclient/persistent_client_registry"
require "ezclient/request"
require "ezclient/response"
require "ezclient/errors"
require "ezclient/check_options"

module EzClient
  def self.new(*args)
    Client.new(*args)
  end

  def self.get_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
