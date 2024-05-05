# Getting Started

## Intro

`Rambla` provides the ability to publish messages to several different destinations. Destinations are supported via handlers. The respective handler must be explicitly included into the list of extra applications of _target application_.

For each of the configured destinations, the pool of workers based on `Finitomata.Pool` is maintained. Each destination should be configured separately; the preferred way would be to use `config.exs` because the handlers themselves are included in the release based on this config. Additional configuration might be passed to the `Rambla.start_link/1` call.

## Configuration

The configuration is the keyword list with keys specifying handlers and their initialization properties. All the configs are based on the pattern provided by [`:amqp`](https://hexdocs.pm/amqp/AMQP.Application.html#get_channel/1-usage) application. 

## Starting Pools

Embed `Rambla` into your supervision tree. The _configured_ handlers will be started supervised.

## Configuration Example

`Rambla.Handlers.Amqp` requires `:amqp` application to be configured and started, ditto for `Rambla.Handlers.S3`. Everything else is to be configured as shown below.

```elixir
config :rambla,
  redis: [
    connections: [
      local_conn: [
        host: System.get_env("REDIS_HOST", "127.0.0.1"),
        port: String.to_integer(System.get_env("REDIS_PORT", "6379")),
        password: System.get_env("REDIS_PASSWORD", ""),
        database: 0
      ]
    ],
    channels: [chan_1: [connection: :local_conn]]
  ],
  httpc: [
    connections: [
      httpbin_success: [scheme: "https", host: "httpbin.org", path: "/post"],
      httpbin_error: [scheme: "https", host: "httpbin.org", path: "/status/500"]
    ],
    channels: [
      chan_1: [connection: :httpbin_success, options: [headers: [{"accept", "application/json"}]]],
      chan_2: [connection: :httpbin_error, options: [headers: [{"accept", "text/plain"}]]]
    ]
  ],
```

## Publishing

Publishing to the destination is as easy, as calling [`Rambla.html#publish/3`](https://hexdocs.pm/rambla/Rambla.html#publish/3) passing the destination channel, the message and optional configuration parameters. The message will be published to all the configured handlers for this channel.

The following would publish the message to previously configured `:channel_1` channel.

```elixir
Rambla.publish(:chan_1, %{message: %{foo: 42, bar: :baz}, exchange: "barfoo"})
```

## Testing

In `:test` environment, use `Rambla.Handlers.Mock` and `Rambla.Handlers.Stub` handlers to substitute actual destinations for the channels and additionally use `Mox` expectations with `Mock` handler to test the publishing.

```elixir
config :rambla,
  mock: [
    connections: [mocked: :conn_mocked],
    channels: [chan_1: [connection: :mocked]]
  ],
  stub: [
    connections: [stubbed: :conn_stubbed],
    channels: [chan_2: [connection: :stubbed]]
  ]
```
