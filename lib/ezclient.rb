# frozen_string_literal: true

require "http"

require_relative "ezclient/version"
require_relative "ezclient/client"
require_relative "ezclient/persistent_client"
require_relative "ezclient/persistent_client_registry"
require_relative "ezclient/request"
require_relative "ezclient/response"
require_relative "ezclient/errors"
require_relative "ezclient/check_options"

module EzClient
  def self.new(*args)
    Client.new(*args)
  end

  def self.get_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
