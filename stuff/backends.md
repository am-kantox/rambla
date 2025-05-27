# Backends

This document provides detailed information about each supported backend in Rambla, including configuration options, usage examples, and common patterns.

## Documentation Index

- [README](../README.md) - Overview and Quick Start
- [Backend Documentation](backends.md) - Detailed backend guide
- [Custom Backends](custom_backends.md) - Creating custom backends
- [Configuration Reference](configuration.md) - Complete configuration guide

## Table of Contents

- [AMQP (RabbitMQ)](#amqp-rabbitmq)
- [Redis](#redis)
- [HTTP](#http)
- [SMTP](#smtp)
- [S3](#s3)
- [ClickHouse](#clickhouse)
- [Common Options](#common-options)

## AMQP (RabbitMQ)

The AMQP backend provides integration with RabbitMQ through the `amqp` library.

### Configuration

```elixir
config :rambla,
  amqp: [
    connections: [
      local_conn: [
        url: "amqp://guest:guest@localhost:5672",
        # or detailed configuration:
        # host: "localhost",
        # port: 5672,
        # username: "guest",
        # password: "guest",
        # virtual_host: "/"
      ]
    ],
    channels: [
      chan_1: [
        connection: :local_conn,
        options: [
          declare?: true,         # Whether to declare exchange on publish
          exchange: "my-exchange",
          routing_key: "my-route",
          callbacks: [
            on_success: fn result -> Logger.info("Published: #{inspect(result)}") end,
            on_failure: fn error -> Logger.error("Failed: #{inspect(error)}") end
          ]
        ]
      ]
    ]
  ]
```

### Usage Examples

```elixir
# Basic publish
Rambla.publish(:chan_1, %{foo: 42})

# With specific exchange and routing key
Rambla.publish(:chan_1, %{
  message: %{foo: 42},
  exchange: "specific-exchange",
  routing_key: "specific-route"
})

# Declare exchange with type
Rambla.publish(:chan_1, %{
  message: %{foo: 42},
  exchange: "my-topic",
  declare?: :topic  # Will declare a topic exchange
})

# Bulk publishing
Rambla.publish(:chan_1, [
  %{message: %{foo: 1}, routing_key: "route1"},
  %{message: %{foo: 2}, routing_key: "route2"}
])
```

## Redis

The Redis backend uses the `redix` library for Redis communication.

### Configuration

```elixir
config :rambla,
  redis: [
    connections: [
      local_conn: [
        host: "localhost",
        port: 6379,
        password: "",  # Optional
        database: 0,
        ssl: false     # Optional
      ]
    ],
    channels: [
      chan_1: [
        connection: :local_conn,
        options: [
          preferred_format: :map,  # :map | :binary | :none
          serializer: Jason       # Optional, defaults to Jason
        ]
      ]
    ]
  ]
```

### Usage Examples

```elixir
# Basic key-value publish
Rambla.publish(:chan_1, %{key: "value"})

# With specific format and serializer
Rambla.publish(:chan_1, %{
  message: %{foo: 42},
  preferred_format: :binary,
  serializer: Jason
})
```

## HTTP

The HTTP backend uses Erlang's built-in `:httpc` module.

### Configuration

```elixir
config :rambla,
  httpc: [
    connections: [
      api_conn: [
        scheme: "https",
        host: "api.example.com",
        path: "/endpoint",
        port: 443           # Optional
      ]
    ],
    channels: [
      chan_1: [
        connection: :api_conn,
        options: [
          headers: [
            {"content-type", "application/json"},
            {"accept", "application/json"}
          ],
          method: :post,    # Default is :post
          timeout: 5000     # Timeout in milliseconds
        ]
      ]
    ]
  ]
```

### Usage Examples

```elixir
# Basic HTTP post
Rambla.publish(:chan_1, %{foo: 42})

# With custom headers and method
Rambla.publish(:chan_1, %{
  message: %{foo: 42},
  headers: [{"x-custom-header", "value"}],
  method: :put
})

# With URI path modification
Rambla.publish(:chan_1, %{
  message: %{foo: 42},
  uri_merge: "/additional/path"
})
```

## SMTP

The SMTP backend uses `gen_smtp` for email delivery.

### Configuration

```elixir
config :rambla,
  smtp: [
    connections: [
      gmail: [
        relay: "smtp.gmail.com",
        port: 587,
        username: "your-email@gmail.com",
        password: "your-password",
        tls: :always,
        auth: :always
      ]
    ],
    channels: [
      chan_1: [
        connection: :gmail,
        options: [
          from: "sender@example.com",
          headers: [
            {"Content-Type", "text/html; charset=UTF-8"}
          ]
        ]
      ]
    ]
  ]
```

### Usage Examples

```elixir
# Send email
Rambla.publish(:chan_1, %{
  to: "recipient@example.com",
  subject: "Test Email",
  body: "Hello from Rambla!"
})

# With HTML content and custom headers
Rambla.publish(:chan_1, %{
  message: %{
    to: "recipient@example.com",
    subject: "HTML Test",
    body: "<h1>Hello</h1><p>This is HTML email</p>"
  },
  headers: [
    {"Content-Type", "text/html; charset=UTF-8"},
    {"X-Priority", "1"}
  ]
})
```

## S3

The S3 backend uses `ex_aws_s3` for Amazon S3 integration.

### Configuration

```elixir
config :rambla,
  s3: [
    connections: [
      default: [
        bucket: "my-bucket",
        region: "eu-west-1"
      ]
    ],
    channels: [
      chan_1: [
        connection: :default,
        options: [
          acl: :private,
          content_type: "application/json"
        ]
      ]
    ]
  ]

# Additional AWS configuration
config :ex_aws,
  access_key_id: "your-access-key",
  secret_access_key: "your-secret-key"
```

### Usage Examples

```elixir
# Upload file to S3
Rambla.publish(:chan_1, %{
  message: "file contents",
  path: "path/to/file.txt"
})

# With custom options
Rambla.publish(:chan_1, %{
  message: Jason.encode!(%{foo: 42}),
  path: "data/record.json",
  acl: :public_read,
  content_type: "application/json"
})
```

## ClickHouse

The ClickHouse backend uses `pillar` for database operations.

### Configuration

```elixir
config :rambla,
  clickhouse: [
    connections: [
      default: [
        host: "localhost",
        port: 8123,
        database: "default",
        username: "default",
        password: ""
      ]
    ],
    channels: [
      chan_1: [
        connection: :default,
        options: [
          table: "events",
          batch_size: 1000  # Optional
        ]
      ]
    ]
  ]
```

### Usage Examples

```elixir
# Insert single record
Rambla.publish(:chan_1, %{
  table: :events,
  message: %{
    timestamp: DateTime.utc_now(),
    event_type: "user_login",
    data: %{user_id: 123}
  }
})

# Batch insert
Rambla.publish(:chan_1, %{
  table: :events,
  message: [
    %{timestamp: DateTime.utc_now(), event_type: "event1"},
    %{timestamp: DateTime.utc_now(), event_type: "event2"}
  ]
})
```

## Common Options

All backends support these common configuration options:

### Channel Options

- `callbacks`: Specify success and failure handlers
  ```elixir
  callbacks: [
    on_success: fn result -> Logger.info("Success: #{inspect(result)}") end,
    on_failure: fn error -> Logger.error("Error: #{inspect(error)}") end
  ]
  ```

### Message Format

- `preferred_format`: Control message serialization
  - `:map` - Automatically decode JSON strings to maps
  - `:binary` - Automatically encode maps to JSON strings
  - `:none` - No automatic conversion

### Retry Configuration

- `retries`: Number of retry attempts (default: 5)
  ```elixir
  config :rambla,
    max_retries: 3
  ```

### Pool Configuration

- `count`: Number of workers in the connection pool
  ```elixir
  config :rambla,
    redis: [
      connections: [
        local_conn: [
          count: 5  # 5 workers in the pool
        ]
      ]
    ]
  ```

For backend-specific options, refer to the respective backend sections above.

## Troubleshooting

Common issues and their solutions:

### Connection Issues

1. **AMQP Connection Failures**
   ```elixir
   {:error, :not_connected}
   ```
   - Check RabbitMQ is running
   - Verify credentials and vhost
   - Ensure port is accessible

2. **Redis Connection Timeouts**
   ```elixir
   {:error, :timeout}
   ```
   - Check Redis server status
   - Verify network connectivity
   - Adjust timeout settings

3. **HTTP Connection Errors**
   ```elixir
   {:error, :econnrefused}
   ```
   - Verify endpoint URL
   - Check firewall settings
   - Validate SSL certificates

### Common Solutions

- Increase logging level for debugging
- Check connection pool settings
- Verify environment variables
- Ensure all dependencies are started

For more details on configuration options, see the [Configuration Guide](configuration.md#error-handling).

