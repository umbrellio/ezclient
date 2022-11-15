# frozen_string_literal: true

module EzClient
  class ResponseStatusError < StandardError
    attr_accessor :response

    def initialize(response)
      self.response = response
      super
    end

    def message
      "Bad response code: #{response.code}"
    end
  end
end
