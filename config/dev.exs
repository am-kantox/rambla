import Config

config :amqp,
  connections: [
    local_conn: [url: "amqp://guest:guest@localhost:5672"]
  ],
  channels: [
    chan_1: [connection: :local_conn]
  ]

config :rambla,
  amqp: [
    host: System.get_env("RABBITMQ_HOST", "127.0.0.1"),
    port: String.to_integer(System.get_env("RABBITMQ_PORT", "5672")),
    username: System.get_env("RABBITMQ_USERNAME", "guest"),
    password: System.get_env("RABBITMQ_PASSWORD", "guest")
  ],
  pools: [
    amqp: [
      options: [size: 5, max_overflow: 0],
      virtual_host: System.get_env("RABBITMQ_VHOST", "/"),
      params: [x_message_ttl: "4000"]
    ]
  ]
