# EzClient   [![Gem Version](https://badge.fury.io/rb/ezclient.svg)](https://badge.fury.io/rb/ezclient) [![Build Status](https://travis-ci.org/umbrellio/ezclient.svg?branch=master)](https://travis-ci.org/umbrellio/ezclient) [![Coverage Status](https://coveralls.io/repos/github/umbrellio/ezclient/badge.svg?branch=master)](https://coveralls.io/github/umbrellio/ezclient?branch=master)

EzClient is [HTTP gem](https://github.com/httprb/http) wrapper for easy persistent connections and more.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "ezclient"
```

## Usage

```ruby
url = "http://example.com"

client_options = { timeout: 10 }
client = EzClient.new(client_options) # => EzClient::Client object

request_options = { params: { a: 1 } }
request = client.request(:get, url, request_options) # => EzClient::Request object

# Performs a GET request to https://example.com/?a=1
response = request.perform # => EzClient::Response object

# Same request but will raise EzClient::ResponseStatusError in case of 4xx or 5xx response code
response = request.perform!

# Alternatively, you can just do:
response = client.perform!(:get, url, request_options) # => EzClient::Response object
```

Valid client options are:

- `api_auth` – arguments for `ApiAuth.sign!` (see https://github.com/mgomes/api_auth)
- `basic_auth` – arguments for basic authentication (either a hash with `:user` and `:pass` keys or a two-element array)
- `cookies` – a hash of cookies (or `HTTP::CookieJar` object) for requests
- `headers` – a hash of headers for requests
- `keep_alive` – timeout for persistent connection in seconds
- `max_retries` – maximum number of retries in case `retry_exceptions` option is provided
- `on_complete` – callback called on request completion
- `on_error` – callback called on request exception
- `on_retry` – callback called on request retry
- `retry_exceptions` – an array of exception classes to retry
- `ssl_context` – ssl context for requests (an `OpenSSL::SSL::SSLContext` instance)
- `timeout` – timeout for requests in seconds or hash like `{ read: 5, write: 5, connect: 1 }`
- `follow` – enable following redirects (`true` or hash with options – e.g. `{ max_hops: 1, strict: false}`)

All these options are passed to each request made by this client but can be overriden on per-request basis.

Extra per-request only options are:

- `body` – raw request body
- `form` – hash for urlencoded body
- `json` – data for json (also adds `application/json` content-type header)
- `metadata` – metadata for request (passed in callbacks)
- `params` – becomes `query` for GET and `form` for other requests
- `query` – hash for uri query

## Persistent connections

If you provide `keep_alive` option to the client or particular request, the connection will be stored in the client and then
reused for all following requests to the same origin within specified amount of time.

Note that if you are using persistent connections, you shouldn't store your client in a variable that is accessable by different threads. See the example:

```ruby
module MyApp
  # Bad: multiple threads will use the same socket
  def self.bad_client
    @ezclient ||= EzClient.new(keep_alive: 100)
  end

  # Good: each thread has it's own socket
  def self.good_client
    Thread.current[:ezclient] ||= EzClient.new(keep_alive: 100)
  end
end
```

Alose note that, as of now, EzClient will
automatically retry the request on any `HTTP::ConnectionError` exception in this case which may possibly result in two requests
received by a server (see https://github.com/httprb/http/issues/459).

## Callbacks and retrying

You can provide `on_complete`, `on_error` and `on_retry` callbacks like this:

```ruby
on_complete = -> (request, response, metadata) { ... }
on_error = -> (request, error, metadata) { ... }
on_retry = -> (request, error, metadata) { ... }

client = EzClient.new(
  on_complete: on_complete,
  on_error: on_error,
  on_retry: on_retry,
  retry_exceptions: [StandardError],
  max_retries: 2,
)

response = client.perform!(:get, url, metadata: :hello)
```

The arguments passed into callbacks are:

- `request` – an `EzClient::Request` instance
- `response` – an `EzClient::Response` instance
- `error` – an exception instance
- `metadata` - the `metadata` option passed into a request

## Request object

```ruby
request = client.request(:post, "http://example.com", json: { a: 1 }, timeout: 15)

request.verb # => "POST"
request.url # => "http://example.com"
request.body # => '{"a": 1}'
request.headers # => { "Content-Type" => "application/json; charset=UTF-8", ... }
```

## Response object

```ruby
response = request.perform(...)

response.body # => String
response.headers # => Hash
response.code # => Integer

response.ok? # Returns if request was 2xx status
response.redirect? # Returns if request was 3xx status
response.client_error? # Returns if request was 4xx status
response.server_error? # Returns if request was 5xx status
response.error? # Returns if request was 4xx or 5xx status
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/umbrellio/ezclient.

## License

Released under MIT License.

## Authors

Created by Yuri Smirnov.

<a href="https://github.com/umbrellio/">
<img style="float: left;" src="https://umbrellio.github.io/Umbrellio/supported_by_umbrellio.svg" alt="Supported by Umbrellio" width="439" height="72">
</a>
