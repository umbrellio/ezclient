# EzClient

EzClient is [HTTP gem](https://github.com/httprb/http) wrapper for easy persistent connections and more.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "ezclient"
gem "http", github: "httprb/http"
```

## Usage
```ruby
client = EzClient.new(client_options)
client.perform!(:get, "https://example.com", params: { a: 1 })
# Performs a GET request to https://example.com/?a=1
```

Valid client options are:
- `api_auth` – arguments for `ApiAuth.sign!`
- `keep_alive` – timeout for persitent connection
- `max_retries` – max number of retries in case of errors
- `on_complete` – callback called on request completion
- `on_error` – callback called on request exception
- `retry_exceptions` – exception classes to retry
- `ssl_context` – ssl context for requests
- `timeout` – timeout for requests

Extra request options are:
- `params` – becomes `query` for GET and `form` for other requests
- `query` – hash for uri query
- `form` – hash for urlencoded body
- `body` – raw body
- `json` – data for json
- `headers` – headers for request

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/umbrellio/ezclient.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
