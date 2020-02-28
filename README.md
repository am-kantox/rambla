# Rambla

![Test](https://github.com/am-kantox/rambla/workflows/Test/badge.svg)  ![Dialyzer](https://github.com/am-kantox/rambla/workflows/Dialyzer/badge.svg)  **Easy publishing to many different targets**

## Installation

```elixir
def deps do
  [
    {:rambla, "~> 0.4"}
  ]
end
```

## Supported back-ends

- Rabbit (through [Amqp](https://hexdocs.pm/amqp/))
- Redis (through [Exredis](https://hexdocs.pm/exredis))
- Http (through [:httpc](http://erlang.org/doc/man/httpc.html))
- Smtp (through [:gen_smtp](https://hexdocs.pm/gen_smtp))
- Slack (through [Envío](https://hexdocs.pm/envio))

## Coming soon

- AWS

## Documentation

- [https://hexdocs.pm/rambla](https://hexdocs.pm/rambla).
