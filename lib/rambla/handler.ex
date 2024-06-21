defmodule Rambla.Handler do
  @moduledoc """
  Default handler for AMQP connections.

  > ### `use Rambla.Handler` {: .info}
  >
  > When you `use Rambla.Handler`, the `Rambla.Handler` module will
  > do the following things for your module:
  >
  > - implement `@behaviour Finitomata.Pool.Actor` where `actor/2` will
  >   delegate to `handle_publish/3` expected to be implemented by this module,
  >   and overridable `on_result/2` and `on_error/2` will have a reasonable
  >   default implementation (debug for the former and warn and retry for the latter)
  > - set `@behaviour Rambla.Handler` to invite you to implement real publishing
  >   handler as `handle_publish/3`

  ### Example

  ```elixir
  defmodule Rambla.Handler.Some do
    use Rambla.Handler

    @impl Rambla.Handler
    def config do
      [
        connections: [
          local_conn: [url: "amqp://guest:guest@localhost:5672"],
        ],
        channels: [
          chan_1: [connection: :local_conn]
        ]
      ]
    end

    @impl Rambla.Handler
    def handle_publish(payload, options, %{connection: conn} = state) do
      SomeImpl.publish(conn, payload, options)
    end 
  end
  ```
  """

  @typedoc "The connection name"
  @type connection_name :: atom()
  @typedoc "The channel name"
  @type channel_name :: atom()
  @typedoc "The allowed callback resolution"
  @type resolution :: :ok | :error | {:ok, term()} | {:error, any()}
  @typedoc "The callback function to be passed to `Rambla.publish/3`"
  @type callback ::
          ([{:source, module()} | {:destination, term()} | {:options, map()}] -> resolution())

  @doc "The callback to be implemented by the consumer of this code"
  @callback handle_publish(
              payload :: callback() | %{message: term()} | term(),
              options :: map(),
              state :: Finitomata.State.payload()
            ) :: resolution()

  @doc "The callback to get to the configuration"
  @callback config :: [
              {:connections, [{connection_name(), keyword() | binary()}]}
              | {:channels,
                 [{channel_name(), [{:connection, connection_name()} | {:options, keyword()}]}]}
            ]

  @doc "The callback to be called when retries exhausted"
  @callback on_fatal(
              Finitomata.id(),
              {nil
               | (any() ->
                    :ok
                    | :retry
                    | {:retry,
                       %{optional(:retries) => non_neg_integer(), optional(:pid) => pid()}}),
               %{
                 required(:payload) => any(),
                 required(:message) => String.t(),
                 retries: non_neg_integer()
               }}
            ) :: :ok

  @doc "If specified, these services will be started before pools under `:rest_for_one`"
  @callback external_servers(Finitomata.Pool.id()) :: [
              Supervisor.module_spec() | Supervisor.child_spec()
            ]

  defmodule RetryState do
    @moduledoc false
    @max_retries Application.compile_env(:rambla, :max_retries, 5)
    defstruct retries: @max_retries, payload: nil
    def max_retries, do: @max_retries
  end

  @doc false
  defmacro __using__(opts \\ []) do
    # credo:disable-for-next-line Credo.Check.Refactor.LongQuoteBlocks
    quote location: :keep, generated: true do
      require Logger
      alias Rambla.Handler.RetryState

      @behaviour Finitomata.Pool.Actor

      defstruct connection: %{}, options: %{}, retries: RetryState.max_retries()

      @doc false
      defp fqn_id(nil), do: __MODULE__
      defp fqn_id(__MODULE__), do: __MODULE__
      defp fqn_id(atom) when is_atom(atom), do: atom |> Atom.to_string() |> fqn_id()
      defp fqn_id(name) when is_binary(name), do: Module.concat(__MODULE__, Macro.camelize(name))

      @doc false
      defp pool_spec(opts \\ []) do
        opts
        |> Keyword.get(:id)
        |> then(&{&1, external_servers(&1)})
        |> do_pool_spec(opts)
      end

      defp do_pool_spec({_, []}, opts) do
        {connection, opts} = Keyword.pop(opts, :connection, %{})
        {options, opts} = Keyword.pop(opts, :options, [])
        {retries, opts} = Keyword.pop(opts, :retries, RetryState.max_retries())

        opts
        |> Keyword.update(:id, __MODULE__, &fqn_id/1)
        |> Keyword.put(:implementation, __MODULE__)
        |> Keyword.put_new(
          :payload,
          struct!(__MODULE__, %{
            connection: connection,
            options: Keyword.merge(unquote(opts), options),
            retries: retries
          })
        )
        |> Finitomata.Pool.pool_spec()
      end

      defp do_pool_spec({id, [_ | _] = external_servers}, opts) do
        %{
          id: {__MODULE__, id},
          start:
            {Supervisor, :start_link,
             [external_servers ++ [do_pool_spec({:void, []}, opts)], [strategy: :rest_for_one]]},
          type: :supervisor
        }
      end

      @doc """
      The list of [`child_spec`](https://hexdocs.pm/elixir/Supervisor.html#t:child_spec/0) returned
        to be embedded into a supervision tree.

      Known options:

      - `connection_options` — a `keyword()` or a function of arity one, which is to receive
        channel names and return connection options as a list
      - `count` — the number of workers in the pool
      - `child_opts` — the options to be passed to the worker’s spec (you won’t need those)

      ### Example
      ```elixir
      Rambla.Handlers.Redis.children_specs(
        connection_options: [exchange: "amq.direct"], count: 3)
      ```
      """
      def children_specs(options \\ []) do
        {connection_options, options} = Keyword.pop(options, :connection_options, [])

        connection_options =
          if is_function(connection_options, 1),
            do: connection_options,
            else: fn _ -> connection_options end

        for {name, params} <- Keyword.get(config(), :channels, []) do
          conn_opts = connection_options.(name)

          # make it `pool_options` if more options are needed
          {count, conn_opts} = Keyword.pop(conn_opts, :count)

          {retries, conn_opts} =
            Keyword.pop(conn_opts, :retries, RetryState.max_retries())

          count
          |> is_nil()
          |> if(do: options, else: Keyword.put(options, :count, count))
          |> Keyword.put(:id, name)
          |> Keyword.put_new(:connection, %{channel: name, params: params})
          |> Keyword.put_new(:options, conn_opts)
          |> Keyword.put_new(:retries, retries)
          |> pool_spec()
        end
      end

      @spec start_link([
              Supervisor.option()
              | Supervisor.init_option()
              | {:connection_options, keyword() | (term() -> keyword())}
              | {:count, non_neg_integer()}
            ]) ::
              Supervisor.on_start()
      @doc "The entry point: this would start a supervisor with all the pools and stuff"
      def start_link(options \\ []) do
        {sup_opts, opts} =
          Keyword.split(
            options,
            ~w|name strategy max_restarts max_seconds max_children extra_arguments|a
          )

        opts |> children_specs() |> Supervisor.start_link([{:strategy, :one_for_one} | sup_opts])
      end

      defoverridable children_specs: 1, start_link: 1

      @doc false
      @spec child_spec([
              Supervisor.option()
              | Supervisor.init_option()
              | {:connection_options, keyword() | (term() -> keyword())}
              | {:count, non_neg_integer()}
            ]) ::
              Supervisor.child_spec()
      def child_spec(options) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [options]},
          type: :worker,
          restart: :permanent,
          shutdown: 5_000
        }
      end

      @impl Finitomata.Pool.Actor
      def actor(payload, %{} = state) when is_list(payload) do
        if Keyword.keyword?(payload),
          do: payload |> Map.new() |> actor(state),
          else: actor(payload, state)
      end

      def actor(%RetryState{payload: payload, retries: retries}, state) do
        actor(payload, %{state | retries: retries})
      end

      def actor(payload, state) do
        options = extract_options(payload, state)

        {retries, payload} =
          if is_map(payload),
            do: Map.pop(payload, :retries, state.retries),
            else: {state.retries, payload}

        on_result = get_in(options, [:callbacks, :on_success])
        on_error = get_in(options, [:callbacks, :on_failure])

        case handle_publish(payload, options, state) do
          {:ok, result} ->
            {:ok, {on_result, result}}

          :ok ->
            {:ok, {on_result, payload}}

          {:error, message} ->
            {:error, {on_error, %{payload: payload, message: message, retries: retries}}}

          :error ->
            {:error,
             {on_error,
              %{
                payload: payload,
                message: "Error publishing message: ‹#{inspect(payload)}›",
                retries: retries
              }}}

          result ->
            {:ok, {on_result, result}}
        end
      end

      @impl Finitomata.Pool.Actor
      def on_result({callback, result}, id) when is_function(callback, 1) do
        with response when response != :ok <-
               callback.(%{id: id, outcome: result, resolution: :success}),
             do: IO.warn("`on_success/1` callback must return `:ok`")
      end

      def on_result({nil, result}, id) do
        Logger.debug("[🖇️] #{__MODULE__}[#{id}] → ✓ " <> inspect(result))
      end

      @impl Finitomata.Pool.Actor
      def on_error({callback, %{retries: retries} = error}, id) when retries <= 0 do
        on_fatal(id, {callback, error})
      end

      def on_error({callback, error}, id) when is_function(callback, 1) do
        response = callback.(%{id: id, outcome: error, resolution: :error})

        case response do
          :ok -> :ok
          :retry -> on_error({nil, error}, id)
          {:retry, opts} -> on_error({nil, Map.merge(error, opts)}, id)
          _ -> IO.warn("`on_failure/1` callback must return `:ok | :retry | {:retry, options}`")
        end
      end

      def on_error({nil, %{payload: payload, message: message} = error}, id) do
        Logger.warning("[🖇️] #{__MODULE__}[#{id}] → ✗ " <> inspect(message))

        retries = Map.get(error, :retries, RetryState.max_retries())
        pid = Map.get(error, :pid, nil)

        Finitomata.Pool.run(id, %RetryState{payload: payload, retries: retries - 1}, pid)
      end

      def extract_options(payload, %{connection: connection, options: options}) do
        payload_options =
          if is_map(payload) and Map.has_key?(payload, :message),
            do: Map.delete(payload, :message),
            else: %{}

        connection_options =
          connection |> get_in([:params, :options]) |> Kernel.||([]) |> Map.new()

        connection_options |> Map.merge(Map.new(options)) |> Map.merge(payload_options)
      end

      defoverridable extract_options: 2

      @doc false
      @spec converter(:none | :map | :binary, any()) :: any()
      defp converter(:map, value) when is_binary(value) do
        case Jason.decode(value) do
          {:ok, map} when is_map(map) -> map
          _ -> value
        end
      end

      defp converter(:binary, value) when is_map(value) do
        case Jason.encode(value) do
          {:ok, binary} when is_binary(binary) -> binary
          _ -> value
        end
      end

      defp converter(_, value), do: value

      @doc """
      An interface to publish messages using the FSM pool.

      The `id` is the specific to an implementation,
        for `Amqp` it’d be the channel name, for instance.

      The second parameter would be a payload, or, if the backend supports it,
        the function of arity one, which would receive back the connection `pid`.

      ### Example

      ```elixir
      Rambla.Handlers.Amqp.publish :channel_name, %{foo: :bar}
      ```
      """
      def publish(id, payload, pid \\ nil)

      def publish(id, payloads, pid) when is_list(payloads) do
        Enum.each(payloads, &publish(id, &1, pid))
      end

      def publish(id, payload, pid) do
        id |> fqn_id() |> Finitomata.Pool.run(payload, pid)
      end

      @behaviour Rambla.Handler

      @impl Rambla.Handler
      def external_servers(_id), do: []

      @impl Rambla.Handler
      def on_fatal(id, {nil, error}) do
        Logger.error("[🖇️] #{__MODULE__}[#{id}] → ✗✗ " <> inspect(error))
      end

      def on_fatal(id, {callback, error}) when is_function(callback, 1) do
        response = callback.(%{id: id, outcome: error, resolution: :fatal})

        case response do
          :ok -> :ok
          :retry -> on_error({nil, Map.put(error, :retries, RetryState.max_retries())}, id)
          {:retry, opts} -> on_error({nil, Map.merge(error, opts)}, id)
          _ -> IO.warn("`on_failure/1` callback must return `:ok | :retry | {:retry, options}`")
        end
      end

      defoverridable external_servers: 1, on_fatal: 2
    end
  end
end
