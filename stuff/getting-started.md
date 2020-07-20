# Getting Started

## Intro

`Rambla` provides the ability to publish messages to several different destinations. Destinations are supported via backends. The respective backend must be explicitly included into the list of extra applications of _target application_.

For each of the configured destinations, the pool of workers to talk to it is maintained. Each destination should be configured separately; the preferred way would be to use `config.exs` for local development and `releases.exs` for releases.

## Configuration

The configuration is the keyword list with keys specifying backends and values—their initialization properties. Properties contain [_pool options_](https://github.com/devinus/poolboy/blob/master/README.md), _name_ and [_type_](https://hexdocs.pm/elixir/GenServer.html?#module-name-registration) of the worker, and _parameters_ to be passed as is to the underlying backend engine.

## Starting Pools

Upon target application start, [`Rambla.start_pools/0`](https://hexdocs.pm/rambla/Rambla.html#start_pools/0) function should be called to start pools. If providing a configuration through the file is not an option, it might be passed as is to the call to [`Rambla.start_pools/1`](https://hexdocs.pm/rambla/Rambla.html#start_pools/1). In this case, the static configuration from config files would be discarded.

## Configuration Example

Most parameters in the options have reasonable default values `:local` for `:type` and backend module name for worker name. Here is the full example, with all the backend on, and options set.

```elixir
config :rambla, :pools,
  redis: [
    params: [
      host: System.get_env("REDIS_HOST", "127.0.0.1"),
      port: String.to_integer(System.get_env("REDIS_PORT", "6379")),
      password: System.get_env("REDIS_PASSWORD", ""),
      database: 0
    ]
  ],
  amqp: [
    options: [size: 5, max_overflow: 300],
    params: [
      host: System.get_env("RABBITMQ_HOST", "127.0.0.1"),
      port: String.to_integer(System.get_env("RABBITMQ_PORT", "5672")),
      username: System.get_env("RABBITMQ_USERNAME", "guest"),
      password: System.get_env("RABBITMQ_PASSWORD", "guest")
      virtual_host: System.get_env("RABBITMQ_VHOST", "/"),
      x_message_ttl: "4000"
    ]
  ],
  http: [
    options: [size: 25],
    params: [
      host: System.get_env("RAMBLA_HTTP_HOST", "127.0.0.1"),
      port: String.to_integer(System.get_env("RAMBLA_HTTP_PORT", "80"))
    ]
  ],
  smtp: [
    options: [max_overflow: 10],
    params: [
      relay: System.get_env("RAMBLA_SMTP_RELAY", "smtp.gmail.com"),
      username: System.get_env("RAMBLA_SMTP_USERNAME"),
      password: System.get_env("RAMBLA_SMTP_PASSWORD"),
      auth: :always,
      ssl: true,
      hostname: System.get_env("RAMBLA_SMTP_HOSTNAME"),
      retries: 3,
      from: %{"Aleksei Matiushkin" => "aleksei@example.com"}
    ]
  ]
```

## Publishing

Publishing to the destination is as easy, as calling [`Rambla.html#publish/3`](https://hexdocs.pm/rambla/Rambla.html#publish/3) passing the destination (e. g. `Rambla.Amqp`,) message and optional configuration parameters.

The following would publish the message to previously configured `AMQP` connection:

```elixir
Rambla.publish(Rambla.Amqp, %{foo: 42, bar: :baz}, exchange: "barfoo")
```
