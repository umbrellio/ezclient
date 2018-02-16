# frozen_string_literal: true

module EzClient
  class ResponseStatusError < StandardError
    attr_accessor :response

    def initialize(response)
      self.response = response
    end
  end
end
