# frozen_string_literal: true

module EzClient::CheckOptions
  def self.call(options, allowed_keys)
    if (options.keys - allowed_keys).any?
      raise ArgumentError, "Unrecognized options: #{options.keys.map(&:inspect).join(", ")}"
    end

    options
  end
end
