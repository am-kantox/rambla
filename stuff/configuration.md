# Configuration Guide

This document provides a comprehensive reference for configuring Rambla, including global settings, backend-specific configurations, and advanced options.

## Documentation Index

- [README](../README.md) - Overview and Quick Start
- [Backend Documentation](backends.md) - Detailed backend guide
- [Custom Backends](custom_backends.md) - Creating custom backends
- [Configuration Reference](configuration.md) - Complete configuration guide

## Table of Contents

- [Basic Configuration](#basic-configuration)
- [Global Settings](#global-settings)
- [Runtime Configuration](#runtime-configuration)
- [Pool Configuration](#pool-configuration)
- [Environment Variables](#environment-variables)
- [Advanced Options](#advanced-options)
- [Best Practices](#best-practices)

## Basic Configuration

Rambla follows a consistent configuration pattern across all backends:

```elixir
config :rambla,
  max_retries: 5,    # Global retry setting
  enable_deprecated: false,  # Disable deprecated functionality
  
  # Backend-specific configurations
  backend_name: [
    connections: [
      connection_name: [
        # Connection parameters
      ]
    ],
    channels: [
      channel_name: [
        connection: :connection_name,
        options: [
          # Channel-specific options
        ]
      ]
    ]
  ]
```

## Global Settings

Global settings affect all backends:

```elixir
config :rambla,
  # Maximum retry attempts for failed operations
  max_retries: 5,
  
  # Enable/disable deprecated functionality
  enable_deprecated: false,
  
  # Default serializer for message encoding/decoding
  serializer: Jason,
  
  # Global logging level
  log_level: :info,
  
  # Explicitly list enabled services
  services: [:amqp, :redis, :http]
```

## Runtime Configuration

Rambla supports runtime configuration through `runtime.exs`:

```elixir
# config/runtime.exs
config :rambla,
  redis: [
    connections: [
      local_conn: [
        host: System.get_env("REDIS_HOST", "localhost"),
        port: String.to_integer(System.get_env("REDIS_PORT", "6379")),
        password: System.get_env("REDIS_PASSWORD", "")
      ]
    ]
  ]
```

## Pool Configuration

Configure connection pools for each backend:

```elixir
config :rambla,
  redis: [
    connections: [
      local_conn: [
        # Number of workers in the pool
        count: 5,
        
        # Maximum number of additional workers
        max_overflow: 10,
        
        # Worker startup options
        worker_options: [
          timeout: 5000
        ]
      ]
    ]
  ]
```

## Environment Variables

Common environment variables used in configuration:

```elixir
# AMQP/RabbitMQ
RABBITMQ_URL="amqp://guest:guest@localhost:5672"
RABBITMQ_HOST="localhost"
RABBITMQ_PORT="5672"
RABBITMQ_USER="guest"
RABBITMQ_PASSWORD="guest"
RABBITMQ_VHOST="/"

# Redis
REDIS_HOST="localhost"
REDIS_PORT="6379"
REDIS_PASSWORD=""
REDIS_DATABASE="0"

# HTTP
HTTP_BASE_URL="https://api.example.com"
HTTP_TIMEOUT="5000"

# SMTP
SMTP_RELAY="smtp.gmail.com"
SMTP_PORT="587"
SMTP_USERNAME="your-email@gmail.com"
SMTP_PASSWORD="your-app-password"

# AWS/S3
AWS_ACCESS_KEY_ID="your-access-key"
AWS_SECRET_ACCESS_KEY="your-secret-key"
AWS_REGION="eu-west-1"
```

## Advanced Options

### Channel Callbacks

Configure success and failure handlers:

```elixir
config :rambla,
  amqp: [
    channels: [
      chan_1: [
        connection: :local_conn,
        options: [
          callbacks: [
            on_success: fn result ->
              Logger.info("Success: #{inspect(result)}")
              :ok
            end,
            on_failure: fn error ->
              Logger.warning("Failed: #{inspect(error)}")
              :retry  # or {:retry, %{retries: 3}}
            end
          ]
        ]
      ]
    ]
  ]
```

### Message Format Control

Configure message serialization:

```elixir
config :rambla,
  redis: [
    channels: [
      chan_1: [
        connection: :local_conn,
        options: [
          # Control message format
          preferred_format: :map,  # :map | :binary | :none
          
          # Custom serializer
          serializer: Jason,
          
          # Serialization options
          json_opts: [pretty: true]
        ]
      ]
    ]
  ]
```

### Error Handling

Configure retry behavior:

```elixir
config :rambla,
  http: [
    channels: [
      chan_1: [
        connection: :api_conn,
        options: [
          # Maximum retry attempts
          retries: 3,
          
          # Backoff strategy
          backoff: [
            type: :exponential,
            initial: 100,
            multiplier: 2,
            max: 1000
          ],
          
          # Fatal error handler
          on_fatal: &MyApp.ErrorHandler.handle_fatal/1
        ]
      ]
    ]
  ]
```

## Best Practices

### 1. Use Environment Variables

Store sensitive information in environment variables:

```elixir
config :rambla,
  amqp: [
    connections: [
      local_conn: [
        url: {:system, "RABBITMQ_URL"},
        # or detailed configuration
        host: {:system, "RABBITMQ_HOST", "localhost"},
        port: {:system, "RABBITMQ_PORT", "5672"} |> String.to_integer(),
        username: {:system, "RABBITMQ_USER"},
        password: {:system, "RABBITMQ_PASSWORD"}
      ]
    ]
  ]
```

### 2. Separate Development and Production Configs

```elixir
# config/dev.exs
config :rambla,
  amqp: [
    connections: [
      local_conn: [url: "amqp://guest:guest@localhost:5672"]
    ]
  ]

# config/prod.exs
config :rambla,
  amqp: [
    connections: [
      prod_conn: [
        url: {:system, "RABBITMQ_URL"},
        ssl_options: [
          verify: :verify_peer,
          cacertfile: "/path/to/ca.crt"
        ]
      ]
    ]
  ]
```

### 3. Use Channel-Specific Options

Configure options per channel for flexibility:

```elixir
config :rambla,
  redis: [
    channels: [
      # Fast, non-critical channel
      events_chan: [
        connection: :local_conn,
        options: [retries: 1, timeout: 1000]
      ],
      
      # Critical channel with retries
      orders_chan: [
        connection: :local_conn,
        options: [retries: 5, timeout: 5000]
      ]
    ]
  ]
```

### 4. Configure Logging

Use appropriate logging levels:

```elixir
config :logger,
  level: :info

config :rambla,
  log_level: :debug,  # More detailed logging for Rambla
  http: [
    channels: [
      chan_1: [
        options: [
          log: true,  # Log HTTP requests
          log_level: :debug
        ]
      ]
    ]
  ]
```

### 5. Testing Configuration

Use mock handlers in test environment:

```elixir
# config/test.exs
config :rambla,
  mock: [
    connections: [mocked: :conn_mocked],
    channels: [chan_1: [connection: :mocked]]
  ],
  stub: [
    connections: [stubbed: :conn_stubbed],
    channels: [chan_2: [connection: :stubbed]]
  ]
```

### 6. Resource Management

Configure pool sizes based on resources:

```elixir
config :rambla,
  redis: [
    connections: [
      local_conn: [
        count: System.schedulers_online(),  # Match CPU cores
        max_overflow: 10,
        worker_options: [
          timeout: 5000,
          max_retries: 3
        ]
      ]
    ]
  ]
```

Remember to adjust these configurations based on your specific needs and environment requirements.

## Version Compatibility

### Rambla 1.3.x
- All features documented here
- Runtime configuration support
- Enhanced error handling

### Rambla 1.2.x
- Basic features
- ClickHouse backend support
- Support for callbacks to control execution

### Rambla 1.1.x and earlier
- Limited backend support
- Different configuration structure
- Consider upgrading for new features

## Troubleshooting Configuration

### Common Configuration Issues

1. **Missing Dependencies**
   ```elixir
   ** (Mix.Error) Could not start application rambla: could not find application :amqp
   ```
   Solution: Add required dependencies to mix.exs:
   ```elixir
   {:amqp, "~> 3.0", optional: true}
   ```

2. **Invalid Configuration**
   ```elixir
   ** (ArgumentError) invalid configuration for :rambla
   ```
   Solution: Verify configuration structure matches the examples in this guide.

3. **Runtime Errors**
   ```elixir
   ** (RuntimeError) no connection configured for :channel_name
   ```
   Solution: Check channel and connection configurations match.

### Monitoring and Metrics

Rambla supports telemetry events:

```elixir
config :telemetry,
  events: [
    [:rambla, :publish, :start],
    [:rambla, :publish, :stop],
    [:rambla, :publish, :exception]
  ]
```

For more details on implementing backends, see the [Custom Backends Guide](custom_backends.md) and for backend-specific options, see the [Backends Documentation](backends.md).

