# frozen_string_literal: true

require "http"
require "ezclient/version"
require "ezclient/client"
require "ezclient/request"
require "ezclient/response"
require "ezclient/errors"

module EzClient
  def self.new(*args)
    Client.new(*args)
  end
end
