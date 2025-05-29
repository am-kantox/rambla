if :clickhouse in Rambla.services() do
  connections =
    :rambla
    |> Application.compile_env(:clickhouse, [])
    |> Keyword.get(:connections, [])
    |> Map.new(fn
      {_conn, :no_pool} ->
        []

      {conn, conn_string} ->
        module =
          Module.concat([Rambla.Services.Clickhouse, conn |> to_string() |> Macro.camelize()])

        use_options =
          case conn_string do
            string when is_binary(string) ->
              [connection_strings: List.wrap(string), name: module]

            {string, opts} ->
              [connection_strings: List.wrap(string), name: module] ++ opts
          end

        defmodule module do
          use Pillar, unquote(use_options)
        end

        {conn, module}
    end)

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

    To install `Clickhouse`, visit https://clickhouse.com/docs

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
    def handle_publish(
          messages,
          options,
          %{connection: %{params: conn_params, channel: name}} = state
        )
        when is_list(messages) do
      case Map.get(unquote(Macro.escape(connections)), Keyword.get(conn_params, :connection)) do
        nil ->
          Enum.each(messages, &handle_publish(&1, options, state))

        mod ->
          messages =
            Enum.map(messages, fn
              %{message: message} -> message
              message -> message
            end)

          do_handle_publish(mod, messages, options, name)
      end
    end

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
          %{connection: %{params: conn_params, channel: name}}
        ) do
      do_handle_publish(
        Map.get(unquote(Macro.escape(connections)), Keyword.get(conn_params, :connection)),
        message,
        options,
        name
      )
    end

    def handle_publish(callback, options, %{connection: %{channel: name}})
        when is_function(callback, 1) do
      callback.(source: __MODULE__, destination: name, options: options)
    end

    def handle_publish(payload, options, state),
      do: handle_publish(%{message: payload}, options, state)

    defp do_handle_publish(nil, message, options, name) do
      with {:ok, table} <- Map.fetch(options, :table) do
        conn = config() |> get_in([:channels, name, :connection])
        conn = config() |> get_in([:connections, conn]) |> Pillar.Connection.new()

        keys = Map.keys(message)
        fields = Enum.join(keys, ", ")
        select = Enum.map_join(keys, ", ", &"{#{&1}}")

        sql = "INSERT INTO #{table} (#{fields}) SELECT #{select}"

        Pillar.insert(conn, sql, message)
      end
    end

    defp do_handle_publish(mod, message, options, _name) do
      with {:ok, table} <- Map.fetch(options, :table),
           do: table |> to_string() |> mod.insert_to_table(message)
    end

    @impl Rambla.Handler
    @doc false
    def config, do: Application.get_env(:rambla, :clickhouse)

    @impl Rambla.Handler
    @doc false
    def external_servers(channel) do
      config()
      |> Keyword.get(:channels, [])
      |> Enum.find(&match?({^channel, _}, &1))
      |> List.wrap()
      |> Enum.flat_map(fn {^channel, kw} ->
        kw |> Keyword.get(:connection, nil) |> List.wrap()
      end)
      |> Enum.map(fn conn ->
        Map.get(unquote(Macro.escape(connections)), conn)
      end)
    end
  end
end
