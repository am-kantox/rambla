import Config

config :rambla,
  redis: [
    host: System.get_env("REDIS_HOST", "127.0.0.1"),
    port: String.to_integer(System.get_env("REDIS_PORT", "6379")),
    password: System.get_env("REDIS_PASSWORD", ""),
    db: 0,
    reconnect: 1_000,
    max_queue: :infinity
  ],
  rabbitmq: [
    host: System.get_env("RABBITMQ_HOST", "127.0.0.1"),
    password: System.get_env("RABBITMQ_PASSWORD", "guest"),
    port: String.to_integer(System.get_env("RABBITMQ_PORT", "5672")),
    username: System.get_env("RABBITMQ_USERNAME", "guest"),
    virtual_host: System.get_env("RABBITMQ_VHOST", "/"),
    x_message_ttl: "4000"
  ]
