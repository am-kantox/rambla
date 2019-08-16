import Config

config :rambla,
  redis: [
    host: "127.0.0.1",
    port: String.to_integer(System.get_env("REDIS_PORT")),
    password: "",
    db: 0,
    reconnect: 1_000,
    max_queue: :infinity
  ],
  rabbitmq: [
    host: "localhost",
    password: "guest",
    port: String.to_integer(System.get_env("RABBITMQ_PORT")),
    username: "guest",
    virtual_host: "/",
    x_message_ttl: "4000"
  ]
