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

config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role],
  hackney_opts: [follow_redirect: true, recv_timeout: 30_000],
  # region: {:system, "AWS_REGION"},
  region: "us-west-1",
  json_codec: Jason,
  normalize_path: false,
  retries: [
    max_attempts: 1,
    base_backoff_in_ms: 10,
    max_backoff_in_ms: 10_000
  ]

config :rambla,
  mock: [
    connections: [mocked: :conn_mocked],
    channels: [chan_0: [connection: :mocked]]
  ],
  stub: [
    connections: [stubbed: :conn_stubbed],
    channels: [chan_stub: [connection: :stubbed]]
  ],
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
  smtp: [
    connections: [
      gmail: [
        # the smtp relay, e.g. "smtp.gmail.com"
        relay: System.get_env("RAMBLA_SMTP_RELAY", "mail.ambment.cat"),
        # the username of the smtp relay e.g. "me@gmail.com"
        username: System.get_env("RAMBLA_SMTP_USERNAME"),
        # the password of the smtp relay e.g. "mypassword"
        password: System.get_env("RAMBLA_SMTP_PASSWORD"),
        # whether the smtp server needs authentication, valid values are if_available and always,
        #   Defaults to if_available. If your smtp relay requires authentication set it to always
        auth: :always,
        # whether to connect on 465 in ssl mode, Defaults to false
        ssl: false,
        # valid values are always, never, if_available.
        #   Most modern smtp relays use tls, so set this to always, Defaults to if_available
        tls: :never,
        # used in ssl:connect, More info at http://erlang.org/doc/man/ssl.html ,
        #   Defaults to [{versions , ['tlsv1', 'tlsv1.1', 'tlsv1.2']}],
        #   This is merged with options listed at: https://github.com/gen-smtp/gen_smtp/blob/master/src/smtp_socket.erl#L46 .
        #   Any options not present in this list will be ignored.
        # tls_options: [versions: [:tlsv1, :"tlsv1.1", :"tlsv1.2"]],
        # the hostname to be used by the smtp relay,
        #   Defaults to: smtp_util:guess_FQDN().
        #   The hostname on your computer might not be correct, so set this to a valid value.
        hostname: System.get_env("RAMBLA_SMTP_HOSTNAME", "ambment.cat"),
        from: %{"Aleksei Matiushkin" => "am@ambment.cat"}
      ]
    ],
    channels: [chan_3: [connection: :gmail, options: [retries: 3]]]
  ],
  s3: [
    connections: [
      bucket_1: [bucket: "test-bucket", path: "some/path"]
    ],
    channels: [
      chan_1: [
        connection: :bucket_1,
        options: [
          connector: Rambla.Mocks.ExAws,
          callbacks: [on_success: fn result -> IO.inspect(result, label: "on_success") && :ok end]
        ]
      ]
    ],
    handler: Rambla.Handlers.S3
  ],

  # ===== << ======
  pools: [
    redis: [
      host: System.get_env("REDIS_HOST", "127.0.0.1"),
      port: String.to_integer(System.get_env("REDIS_PORT", "6379")),
      password: System.get_env("REDIS_PASSWORD", ""),
      database: 0
    ],
    amqp: [
      host: System.get_env("RABBITMQ_HOST", "127.0.0.1"),
      port: String.to_integer(System.get_env("RABBITMQ_PORT", "5672")),
      username: System.get_env("RABBITMQ_USERNAME", "guest"),
      password: System.get_env("RABBITMQ_PASSWORD", "guest"),
      options: [size: 5, max_overflow: 0],
      virtual_host: System.get_env("RABBITMQ_VHOST", "/"),
      params: [x_message_ttl: "4000"]
    ]
  ]
