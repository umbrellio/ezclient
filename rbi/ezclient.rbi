# typed: strong

module EzClient
  sig { params(options: T::Hash[T.untyped, T.untyped]).void }
  def self.new(options = {}); end
end

class EzClient::Client
  sig { params(options: T::Hash[T.untyped, T.untyped]).void }
  def initialize(options = {}); end

  sig { params(verb: Symbol, url: String, options: T::Hash[Symbol, T.untyped]).returns(EzClient::Request) }
  def request(verb, url, options = {}); end

  sig { params(verb: Symbol, url: String, options: T::Hash[Symbol, T.untyped]).returns(EzClient::Response) }
  def perform(verb, url, options = {}); end

  sig { params(verb: Symbol, url: String, options: T::Hash[Symbol, T.untyped]).returns(EzClient::Response) }
  def perform!(verb, url, options = {}); end

  sig { params(url: String, timeout: Numeric).returns(String) }
  def persistent_client_for(url, timeout:); end
end

class EzClient::Request
  sig { params(verb: Symbol, url: String, options: T::Hash[Symbol, T.untyped]).void }
  def initialize(verb, url, options); end

  sig { returns(String) }
  def verb; end

  sig { returns(String) }
  def url; end

  sig { returns(T::Hash[Symbol, T.untyped]) }
  def options; end

  sig { returns(EzClient::Response) }
  def perform; end

  sig { returns(EzClient::Response) }
  def perform!; end

  sig { params(args: T.untyped).void }
  def api_auth!(*args); end

  sig { returns(String) }
  def uri; end

  sig { returns(String) }
  def body; end

  sig { returns(String) }
  def headers; end

  sig { params(new_headers: String).returns(String) }
  def add_headers!(new_headers); end

  sig { returns(String) }
  def http_options; end

  private

  sig { returns(HTTP::Client) }
  def client; end

  sig { returns(HTTP::Request) }
  def http_request; end

  sig { returns(HTTP::Client) }
  def http_client; end

  sig { returns(HTTP::Response) }
  def perform_request; end

  sig { returns(T.untyped) }
  def with_retry(&block); end

  sig { params(block: T.proc.void).void }
  def retry_on_connection_error(&block); end

  sig { returns(T.nilable(Float)) }
  def timeout; end

  sig { returns(T.proc.params(arg0: EzClient::Request, arg1: EzClient::Response, arg2: T.untyped).void) }
  def on_complete; end

  sig { returns(T.proc.params(arg0: EzClient::Request, arg1: Exception, arg2: T.untyped).void) }
  def on_error; end

  sig { returns(T.proc.params(arg0: EzClient::Request, arg1: Exception, arg2: T.untyped).void) }
  def on_retry; end

  sig { returns(T::Array[T.untyped]) }
  def retried_exceptions; end

  sig { returns(Integer) }
  def max_retries; end

  sig { returns(T.nilable(T::Hash[T.untyped, T.untyped])) }
  def follow; end

  sig { params(headers: String).returns(String) }
  def prepare_headers(headers); end

  sig {params(original_params: T.untyped).returns(T::Hash[T.untyped, T.untyped])}
  def prepare_form_params(original_params); end

  sig { params(client: HTTP::Client).returns(HTTP::Client) }
  def set_timeout(client); end

  sig { returns(T.untyped) }
  def basic_auth; end
end

module EzClient::CheckOptions
  sig { params(options: T::Hash[Symbol, T.untyped], allowed_keys: T::Array[Symbol]).returns(T::Hash[Symbol, T.untyped]) }
  def self.call(options, allowed_keys); end
end

class EzClient::ResponseStatusError < StandardError
  sig { params(response: EzClient::Response).void }
  def initialize(response); end

  sig { returns(String) }
  def message; end

  sig { returns(EzClient::Response) }
  def response; end
end

class EzClient::Response
  sig { returns(HTTP::Response) }
  def http_response; end

  sig { returns(String) }
  def body; end

  sig { params(http_response: HTTP::Response).void }
  def initialize(http_response); end

  sig { returns(HTTP::Headers) }
  def headers; end

  sig { returns(Integer) }
  def code; end

  sig { returns(HTTP::Cookie) }
  def cookies; end

  sig { returns(T::Boolean) }
  def ok?; end

  sig { returns(T::Boolean) }
  def redirect?; end

  sig { returns(T::Boolean) }
  def client_error?; end

  sig { returns(T::Boolean) }
  def server_error?; end

  sig { returns(T::Boolean) }
  def error?; end
end
