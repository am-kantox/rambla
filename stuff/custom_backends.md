# Custom Backends

This guide explains how to create custom backends for Rambla by implementing the required behaviours and callbacks.

## Documentation Index

- [README](../README.md) - Overview and Quick Start
- [Backend Documentation](backends.md) - Detailed backend guide
- [Custom Backends](custom_backends.md) - Creating custom backends
- [Configuration Reference](configuration.md) - Complete configuration guide

## Table of Contents

- [Basic Structure](#basic-structure)
- [Required Callbacks](#required-callbacks)
- [Configuration](#configuration)
- [Error Handling](#error-handling)
- [Complete Example](#complete-example)

## Basic Structure

To create a custom backend, you need to:

1. Create a new module under your application
2. Use the `Rambla.Handler` behaviour
3. Implement the required callbacks
4. Configure your backend

Here's the basic structure:

```elixir
defmodule MyApp.Handlers.Custom do
  @moduledoc """
  Custom backend implementation for MyApp.
  """
  use Rambla.Handler

  # Required callbacks will go here
end
```

## Required Callbacks

### handle_publish/3

The main callback that handles message publishing. It receives:

- `payload` - The message to be published
- `options` - Publishing options
- `state` - The current handler state

```elixir
@impl Rambla.Handler
def handle_publish(payload, options, state)

# For direct message handling
def handle_publish(%{message: message}, options, %{connection: %{channel: name}}) do
  # Handle the message
  case publish_to_my_service(message, options) do
    :ok -> {:ok, message}
    {:error, reason} -> {:error, reason}
  end
end

# For function-based handling
def handle_publish(callback, options, %{connection: %{channel: name}})
    when is_function(callback, 1) do
  callback.(source: __MODULE__, destination: name, options: options)
end

# Fallback for raw messages
def handle_publish(payload, options, state) do
  handle_publish(%{message: payload}, options, state)
end
```

### config/0

Returns the configuration structure for your backend:

```elixir
@impl Rambla.Handler
def config do
  Application.get_env(:my_app, :my_backend, [])
end
```

### external_servers/1 (optional)

If your backend needs additional services to be started before the pool:

```elixir
@impl Rambla.Handler
def external_servers(channel) do
  [
    {MyApp.Service, name: service_name(channel)}
  ]
end
```

## Configuration

Your backend should follow Rambla's configuration pattern:

```elixir
# config/config.exs
config :my_app, :my_backend,
  connections: [
    default_conn: [
      host: "example.com",
      port: 1234,
      # other connection options
    ]
  ],
  channels: [
    chan_1: [
      connection: :default_conn,
      options: [
        # channel-specific options
      ]
    ]
  ]
```

## Error Handling

Rambla provides built-in error handling and retry mechanisms. Your `handle_publish/3` implementation should return:

- `{:ok, result}` - Successful publish
- `:ok` - Successful publish without result
- `{:error, reason}` - Failed publish with reason
- `:error` - Failed publish without specific reason

The handler will automatically:

1. Retry failed operations (up to configured max_retries)
2. Call success/failure callbacks
3. Log appropriate messages

## Complete Example

Here's a complete example of a custom backend:

```elixir
defmodule MyApp.Handlers.Custom do
  @moduledoc """
  Custom backend implementation for MyApp.
  """
  use Rambla.Handler
  require Logger

  @impl Rambla.Handler
  def handle_publish(%{message: message}, options, %{connection: %{channel: name}}) do
    %{host: host, port: port} = get_in(options, [:connection, :params])
    
    case MyService.publish(host, port, message) do
      :ok -> 
        {:ok, message}
      {:error, reason} -> 
        {:error, "Failed to publish: #{inspect(reason)}"}
    end
  end

  def handle_publish(callback, options, %{connection: %{channel: name}})
      when is_function(callback, 1) do
    callback.(source: __MODULE__, destination: name, options: options)
  end

  def handle_publish(payload, options, state) do
    handle_publish(%{message: payload}, options, state)
  end

  @impl Rambla.Handler
  def config do
    [
      connections: [
        default: [
          host: "localhost",
          port: 4000,
          timeout: 5000
        ]
      ],
      channels: [
        chan_1: [
          connection: :default,
          options: [
            retries: 3,
            callbacks: [
              on_success: &handle_success/1,
              on_failure: &handle_failure/1
            ]
          ]
        ]
      ]
    ]
  end

  @impl Rambla.Handler
  def external_servers(channel) do
    [{MyApp.Service, name: service_name(channel)}]
  end

  # Optional callback implementations
  @impl Rambla.Handler
  def on_fatal(id, {nil, error}) do
    Logger.error("[MyBackend] Fatal error on #{id}: #{inspect(error)}")
    super(id, {nil, error})
  end

  # Private functions
  defp handle_success(%{id: id, outcome: result}) do
    Logger.info("[MyBackend] Successfully published on #{id}: #{inspect(result)}")
    :ok
  end

  defp handle_failure(%{id: id, outcome: error}) do
    Logger.warning("[MyBackend] Failed to publish on #{id}: #{inspect(error)}")
    :retry
  end

  defp service_name(channel) do
    Module.concat([MyApp.Service, channel])
  end
end
```

### Usage

Once implemented, configure your backend in your application:

```elixir
# config/config.exs
config :my_app, :my_backend,
  connections: [
    local: [
      host: "localhost",
      port: 4000
    ]
  ],
  channels: [
    chan_1: [
      connection: :local,
      options: [
        timeout: 5000
      ]
    ]
  ]

# Add to your application supervisor
children = [
  MyApp.Handlers.Custom
]
```

Then use it like any other Rambla backend:

```elixir
Rambla.publish(:chan_1, %{my: "message"})
```

## Integration with Existing Systems

Your custom backend can integrate with any external system:

- Message queues
- Databases
- APIs
- File systems
- Custom protocols
- Internal services

Just implement the appropriate client code in your `handle_publish/3` callback.

## Testing

Create test helpers for your backend:

```elixir
defmodule MyApp.Handlers.CustomTest do
  use ExUnit.Case
  
  setup do
    start_supervised!(MyApp.Handlers.Custom)
    :ok
  end
  
  test "publishes message successfully" do
    assert :ok = Rambla.publish(:test_chan, %{test: true})
  end
end
```

For integration testing, consider implementing a mock version of your backend using `Rambla.Handlers.Mock`.

## Troubleshooting Custom Backends

Common implementation issues:

1. **Pool Configuration**
   - Ensure `external_servers/1` returns correct child specs
   - Verify pool size settings
   - Check worker initialization

2. **Message Handling**
   - Validate message format conversion
   - Handle all error cases
   - Implement proper cleanup

3. **Integration Issues**
   - Check service dependencies
   - Verify connection parameters
   - Test failure scenarios

4. **Common Errors**
   - `undefined function handle_publish/3` - Ensure you've implemented all required callbacks
   - `no function clause matching` - Check pattern matching in your handle_publish functions
   - `no process` - Verify your external service is running before the handler starts

See the [Configuration Guide](configuration.md) for detailed settings and [Backends Documentation](backends.md) for example implementations.

