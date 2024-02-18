defmodule Rambla do
  @moduledoc """
  Interface for the message publishing through `Rambla`.

  `Rambla` maintains connection pools with `Finitomata.Pool` for each service.

  The typical config for `Rambla` service follows the pattern introduced by
    `AMQP` library:

  ```elixir
  ‹service›: [
    connections: [
      ‹connection_name›: [‹key_1›: ‹value_1›, …]
    ],
    channels: [
      ‹channel_name›: [
        connection: ‹connection_name›,
        options: [‹key_1›: ‹value_1›, …]
      ]
    ]
  ]
  ```

  Channel names are used across connections to publish messages.
    `Rambla.publish(:channel_1, message)` would publish the message to all channels
    named `channel_1`.
  """

  @channels for {service, opts} <-
                  Application.get_all_env(:rambla) ++ [{:amqp, Application.get_all_env(:amqp)}],
                {:channels, opts} <- opts,
                {name, _} <- opts,
                reduce: %{},
                do: (acc -> Map.update(acc, name, [service], &[service | &1]))

  @doc "Returns a map `%{‹service› => [‹channels›]}`"
  def channels, do: @channels

  @doc false
  def handler_for_service(name) do
    case Application.get_env(:rambla, name) do
      [{_, _} | _] = cfg -> Keyword.get(cfg, :handler)
      _ -> nil
    end || Module.concat(Rambla.Handlers, name |> to_string() |> Macro.camelize())
  end

  @enable_deprecated Application.compile_env(:rambla, :enable_deprecated, true)

  if @enable_deprecated do
    @doc """
    Starts the pools configured in the `config.exs` / `releases.exs` file.

    This call is equivalent to `start_pools(Application.get_env(:rambla, :pools))`.
    """
    @doc deprecated: "Use configuration instead"
    def start_pools do
      IO.warn("This call is deprecated and will be removed")
      Rambla.ConnectionPool.start_pools()
    end

    @doc "Starts the pools as specified by options (`map()` or `keyword()`)"
    @doc deprecated: "Use configuration instead"
    def start_pools(opts) do
      IO.warn("This call is deprecated and will be removed")
      Rambla.ConnectionPool.start_pools(opts)
    end

    @doc "Returns the currently active pools"
    @doc deprecated: "Use configuration instead"
    def pools do
      IO.warn("This call is deprecated and will be removed")
      Rambla.ConnectionPool.pools()
    end
  end

  @doc """
  Publishes the message to the target channels. The message structure depends on
  the destination. For `RabbitMQ` is might be whatever, for `Smtp` it expects
  to have `to:`, `subject:` and `body:` fields.
  """
  def publish(target, message, pid \\ nil)

  if @enable_deprecated do
    def publish(target, message, opts) when is_tuple(target) or is_map(opts) do
      IO.warn("This call is deprecated and will be removed")
      Rambla.ConnectionPool.publish(target, message, opts || %{})
    end

    def publish(target, message, opts) when target in [:amqp, :redis, :http, :smtp, :process] do
      IO.warn("This call is deprecated and will be removed")
      Rambla.ConnectionPool.publish(target, message, opts || %{})
    end

    def publish(target, message, opts)
        when target in [Rambla.Amqp, Rambla.Redis, Rambla.Http, Rambla.Smtp, Rambla.Process] do
      IO.warn("This call is deprecated and will be removed")
      Rambla.ConnectionPool.publish(target, message, opts || %{})
    end
  end

  def publish(channels, message, pid) when not is_list(channels) do
    publish([channels], message, pid)
  end

  def publish(channels, message, pid) do
    for channel <- channels,
        service <- Map.get(@channels, channel, []),
        handler <- [handler_for_service(service)] do
      handler.publish(channel, message, pid)
    end
  end

  if @enable_deprecated do
    @doc """
    Publishes the message to the destination synchronously, avoiding the pool.
    """
    @doc deprecated: "Use configuration instead"
    defdelegate publish_synch(target, message), to: Rambla.ConnectionPool

    @doc """
    Publishes the message to the destination synchronously, avoiding the pool.
    Unlike `publish_synch/2`, allows to specify additional options per request.
    """
    @doc deprecated: "Use configuration instead"
    defdelegate publish_synch(target, message, opts), to: Rambla.ConnectionPool

    @doc """
    Executes any arbitrary function in the context of one of workers in the
    respective connection pool for the target.

    The function would receive a pid of the connection process.
    """
    defdelegate raw(target, f), to: Rambla.ConnectionPool
  end
end
