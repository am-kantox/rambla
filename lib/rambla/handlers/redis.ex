if :redis in Rambla.services() do
  defmodule Rambla.Handlers.Redis do
    @moduledoc """
    Default handler for _Redis_ connections. For this handler to work properly,
      one must configure it with 

    ```elixir
    config :rambla, :redis,
      connections: [
        local_conn: "redis://localhost:6379/0",
        remote_conn: [host: "example.com", port: 6379, database: 0]
      ],
      channels: [
        chan_1: [connection: :local_conn]
      ]

    # Then you can access the connection/channel via `Rambla.Handlers.Amqp` as

    Rambla.Handlers.Redis.publish(:chan_1, %{message: %{foo: 42}, serializer: Jason})
    ```
    """

    use Rambla.Handler

    @impl Rambla.Handler
    @doc false
    def handle_publish(%{message: message}, options, %{connection: %{channel: name}}) do
      {preferred_format, options} = Map.pop(options, :preferred_format, :map)
      {serializer, _options} = Map.pop(options, :serializer, Jason)

      results =
        for {k, v} <- converter(preferred_format, message) do
          value =
            case serializer.encode(v) do
              {:ok, json} -> json
              {:error, _} -> inspect(v)
            end

          case Redix.command(name, ["SET", to_string(k), value]) do
            {:ok, %Redix.Error{} = error} -> {:error, error}
            {:ok, redis_value} -> {:ok, redis_value}
            {:error, error} -> {:error, error}
          end
        end

      results
      |> Enum.reduce({[], []}, fn
        {:ok, result}, {results, errors} -> {[result | results], errors}
        {:error, error}, {results, errors} -> {results, [error | errors]}
      end)
      |> case do
        {results, []} -> {:ok, results}
        {results, errors} -> {:error, %{failures: errors, successes: results}}
      end
    end

    def handle_publish(callback, options, %{connection: %{channel: name}})
        when is_function(callback, 1) do
      callback.(source: __MODULE__, destination: name, options: options)
    end

    def handle_publish(payload, options, state),
      do: handle_publish(%{message: payload}, options, state)

    @impl Rambla.Handler
    @doc false
    def config, do: Application.get_env(:rambla, :redis)

    @impl Rambla.Handler
    @doc false
    def external_servers(id) do
      [{Redix, name: id}]
    end
  end
end
