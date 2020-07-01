import Config

config :rambla,
  amqp: [
    host: System.get_env("RABBITMQ_HOST", "127.0.0.1"),
    port: String.to_integer(System.get_env("RABBITMQ_PORT", "5672")),
    username: System.get_env("RABBITMQ_USERNAME", "guest"),
    password: System.get_env("RABBITMQ_PASSWORD", "guest")
  ],
  pools: [
    amqp: [
      pool: [size: 10, max_overflow: 20],
      virtual_host: System.get_env("RABBITMQ_VHOST", "/"),
      x_message_ttl: "4000"
    ]
  ]
