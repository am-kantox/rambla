# Rambla    [![Kantox ❤ OSS](https://img.shields.io/badge/❤-kantox_oss-informational.svg)](https://kantox.com/)  ![Test](https://github.com/am-kantox/rambla/workflows/Test/badge.svg)  ![Dialyzer](https://github.com/am-kantox/rambla/workflows/Dialyzer/badge.svg)

**Easy publishing to many different targets**

## Installation

```elixir
def deps do
  [
    {:rambla, "~> 0.4"}
  ]
end
```

## Supported backends

- Rabbit (through [Amqp](https://hexdocs.pm/amqp/))
- Redis (through [Redix](https://hexdocs.pm/redix))
- Http (through [:httpc](http://erlang.org/doc/man/httpc.html))
- Smtp (through [:gen_smtp](https://hexdocs.pm/gen_smtp))
- S3 (through [:ex_aws_s3](https://hexdocs.pm/ex_aws_s3))
- Slack (through [Envío](https://hexdocs.pm/envio)) [pending]

## Coming soon

- AWS

## Changelog

- **`1.1.0`** Complete rewrite, all the services are now controlled by `Finitomata.Pool`
- **`1.0.0`** Modern era update
- **`0.16.3`** Better error reporting, logging of insuccessfuly HTTP requests
- **`0.16.0`** Several instances of service + Mocks
- **`0.15.0`** Hashring for selecting channels in AMQP backend within a single connection
- **`0.14.4`** Accept headers for `:httpc` as map/keyword of binaries, `:gen_server_timeout` for `publish_synch/3`
- **`0.14.0`** Use Tarearbol.Pool to manage channels behind AMQP connections
- **`0.13.0`** Filter out connection params from logs
- **`0.12.0`** `Rambla.publish_synch/3` to avoid pool while publishing
- **`0.11.1`** Optional Boundary support for Telemetria
- **`0.11.0`** Envío → Telemetria
- **`0.9.3`** Envío broadcast to `:rambla` channel, with a type
- **`0.9.0`** Divorce `Rambla` with `AMQP` and `Envio`
- **`0.8.0`** `Rambla.raw/2` returning a worker from pool
- **`0.6.5`** `RabbitMQ` → `bind`, `unbind`
- **`0.6.3`** Auto-reenable tasks
- **`0.6.2`** code cleanup, DRY
- **`0.6.0`** `mix` tasks to deal with RabbitMQ
- **`0.5.2`** graceful timeout, fix for optional `Envio` does not included
- **`0.5.1`** performance fixes, do not require `queue` in call to Rabbit `publish/2`, `declare?: false` to not declare exchange every time
- **`0.5.0`** bulk publisher
- **`0.4.0`** `SMTP` publisher
- **`0.3.0`** `HTTP` publisher

## Documentation

- [https://hexdocs.pm/rambla](https://hexdocs.pm/rambla).
