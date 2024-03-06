if :clickhouse in Rambla.services() do
  defmodule Rambla.Handlers.Clickhouse do
    @moduledoc """
    Default handler for _Clickhouse_ connections. For this handler to work properly,
      one must configure it with 

    ```elixir
    config :rambla, :clickhouse,
      connections: [
        conn_1: "http://default:password@host-master-1:8123/database"
      ],
      channels: [
        chan_1: [connection: :conn_1]
      ]

    # Then you can access the connection/channel via `Rambla.Handlers.Clickhouse` as

    Rambla.Handlers.Clickhouse.publish(:chan_1, %{message: %{foo: 42}, table: :events, serializer: Jason})
    ```

    ---

    To install `Clickhouse`, visit https://clickhouse.com/docs/en/getting-started

    ```sql
    CREATE TABLE events
    (
      source_id UInt32,
      timestamp DateTime,
      message String
    )
    ENGINE = MergeTree
    PRIMARY KEY (source_id, timestamp)
    ```
    """

    use Rambla.Handler

    @impl Rambla.Handler
    @doc false
    def handle_publish(%{message: message}, options, state) when is_binary(message) do
      {serializer, options} = Map.pop(options, :serializer, Jason)

      case serializer.decode(message) do
        {:ok, %{} = map} -> handle_publish(%{message: map}, options, state)
        {:ok, not_map} -> {:error, "Only maps can be published, given: ‹#{inspect(not_map)}›"}
        {:error, error} -> {:error, error}
      end
    end

    def handle_publish(
          %{message: %{} = message},
          options,
          %{connection: %{channel: name}}
        ) do
      with {:ok, table} <- Map.fetch(options, :table) do
        conn = config() |> get_in([:channels, name, :connection])
        conn = config() |> get_in([:connections, conn]) |> Pillar.Connection.new()

        keys = Map.keys(message)
        fields = Enum.join(keys, ", ")
        select = Enum.map_join(keys, ", ", &"{#{&1}}")

        Pillar.insert(conn, "INSERT INTO #{table} (#{fields}) SELECT #{select}", message)
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
    def config, do: Application.get_env(:rambla, :clickhouse)
  end
end
