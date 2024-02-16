defmodule Rambla.Handler do
  @moduledoc """
  Default handler for AMQP connections.

  > ### `use Rambla.Handler` {: .info}
  >
  > When you `use Rambla.Handler`, the `Rambla.Handler` module will
  > do the following things for your module:
  >
  > - implement `@behaviour Finitomata.Pool.Actor` where `actor/2` will
  >   delegate to `handle_publish/2` expected to be implemented by this module,
  >   and overridable `on_result/2` and `on_error/2` will have a reasonable
  >   default implementation (debug for the former and warn and retry for the latter)
  > - set `@behaviour Rambla.Handler` to invite you to implement real publishing
  >   handler as `handle_publish/2`

  ### Example

  ```elixir
  defmodule Rambla.Handler.Some do
    use Rambla.Handler

    @impl Rambla.Handler
    def handle_publish(payload, %{connection: conn} = state) do
      SomeImpl.publish(conn, payload, state.options)
    end 
  end
  ```
  """

  @typedoc "Callback resolution"
  @type resolution :: :ok | :error | {:ok, term()} | {:error, any()}

  @doc "The callback to be implemented by the consumer of this code"
  @callback handle_publish(
              (pid() -> resolution()) | %{message: term()} | term(),
              Finitomata.State.payload()
            ) :: resolution()

  @doc false
  defmacro __using__(opts \\ []) do
    quote location: :keep, generated: true do
      require Logger

      @behaviour Finitomata.Pool.Actor

      defstruct connection: %{}, options: %{}

      @doc false
      defp fqn_id(nil), do: __MODULE__
      defp fqn_id(__MODULE__), do: __MODULE__
      defp fqn_id(atom) when is_atom(atom), do: atom |> Atom.to_string() |> fqn_id()
      defp fqn_id(name) when is_binary(name), do: Module.concat(__MODULE__, Macro.camelize(name))

      @doc false
      def child_spec(opts \\ []) do
        {connection, opts} = Keyword.pop(opts, :connection, %{})
        {options, opts} = Keyword.pop(opts, :options, [])

        opts
        |> Keyword.update(:id, __MODULE__, &fqn_id/1)
        |> Keyword.put(:implementation, __MODULE__)
        |> Keyword.put_new(
          :payload,
          struct!(__MODULE__, %{
            connection: connection,
            options: Keyword.merge(unquote(opts), options)
          })
        )
        |> Finitomata.Pool.pool_spec()
      end

      @impl true
      def actor(payload, %{} = state) when is_list(payload) do
        if Keyword.keyword?(payload),
          do: payload |> Map.new() |> actor(state),
          else: actor(payload, state)
      end

      def actor(payload, state) do
        case handle_publish(payload, state) do
          {:ok, result} ->
            {:ok, result}

          :ok ->
            {:ok, payload}

          {:error, message} ->
            {:error, %{payload: payload, message: message}}

          :error ->
            {:error,
             %{payload: payload, message: "Error publishing message: ‹#{inspect(payload)}›"}}
        end
      end

      @impl true
      def on_result(result, id) do
        Logger.debug("[🖇️] #{__MODULE__}[#{id}] → ✓ " <> inspect(result))
      end

      @impl true
      def on_error(error, id) do
        Logger.warning("[🖇️] #{__MODULE__}[#{id}] → ✗ " <> inspect(error))
        Finitomata.Pool.run(id, :atom, nil)
      end

      defoverridable on_result: 2, on_error: 2

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
      def publish(id, payload) do
        id |> fqn_id() |> Finitomata.Pool.run(payload, nil)
      end

      @behaviour Rambla.Handler
    end
  end
end
