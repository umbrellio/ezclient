# frozen_string_literal: true

# typed: strict

class EzClient::Response
  attr_reader :http_response, :body

  def initialize(http_response)
    @http_response = T.let(http_response, HTTP::Response)

    # Make sure we read the body for persistent connection
    @body = T.let(http_response.body.to_s, String)
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
