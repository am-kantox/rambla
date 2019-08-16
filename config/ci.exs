import Config

config :rambla,
  redis: [
    host: System.get_env("REDIS_HOST"),
    port: String.to_integer(System.get_env("REDIS_PORT", "6379")),
    password: "",
    db: 0,
    reconnect: 1_000,
    max_queue: :infinity
  ],
  rabbitmq: [
    host: System.get_env("RABBITMQ_HOST"),
    password: "guest",
    port: String.to_integer(System.get_env("RABBITMQ_PORT", "5672")),
    username: "guest",
    virtual_host: "/",
    x_message_ttl: "4000"
  ]
