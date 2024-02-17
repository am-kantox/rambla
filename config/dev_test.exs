import Config

config :amqp,
  connections: [
    local_conn: [url: "amqp://guest:guest@localhost:5672"],
    other_conn: [
      host: System.get_env("RABBITMQ_HOST", "127.0.0.1"),
      port: String.to_integer(System.get_env("RABBITMQ_PORT", "5672")),
      username: System.get_env("RABBITMQ_USERNAME", "guest"),
      password: System.get_env("RABBITMQ_PASSWORD", "guest"),
      virtual_host: System.get_env("RABBITMQ_VHOST", "/"),
      params: [x_message_ttl: "4000"]
    ]
  ],
  channels: [chan_1: [connection: :local_conn]]

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
  # ===== << ======
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
