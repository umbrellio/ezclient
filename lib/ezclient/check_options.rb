# frozen_string_literal: true
# typed: strict

module EzClient::CheckOptions
  def self.call(options, allowed_keys)
    unknown_keys = options.keys - allowed_keys

    if unknown_keys.any?
      raise ArgumentError, "Unrecognized options: #{unknown_keys.map(&:inspect).join(", ")}"
    end

    options
  end
end
