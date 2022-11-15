# frozen_string_literal: true

class EzClient::Response
  attr_accessor :http_response, :body, :elapsed_seconds

  def initialize(http_response, elapsed_seconds)
    self.http_response = http_response
    self.body = http_response.body.to_s # Make sure we read the body for persistent connection
    self.elapsed_seconds = elapsed_seconds
  end

  def headers
    http_response.headers
  end

  def code
    http_response.code
  end
  alias status code

  def cookies
    http_response.cookies
  end

  def ok?
    code.between?(200, 299)
  end

  def redirect?
    code.between?(300, 399)
  end

  def client_error?
    code.between?(400, 499)
  end

  def server_error?
    code.between?(500, 599)
  end

  def error?
    client_error? || server_error?
  end
end
