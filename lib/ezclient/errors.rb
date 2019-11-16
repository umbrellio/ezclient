# frozen_string_literal: true

# typed: strong

module EzClient
  class ResponseStatusError < StandardError
    attr_reader :response

    def initialize(response)
      @response = T.let(response, EzClient::Response)
    end

    def message
      "Bad response code: #{response.code}"
    end
  end
end
