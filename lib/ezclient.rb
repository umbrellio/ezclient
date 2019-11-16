# frozen_string_literal: true
# typed: strict

require "http"
require "ezclient/version"
require "ezclient/client"
require "ezclient/request"
require "ezclient/response"
require "ezclient/errors"
require "ezclient/check_options"

module EzClient
  def self.new(options = {})
    Client.new(options)
  end
end
