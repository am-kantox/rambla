defmodule Rambla.Handlers.Amqp do
  @moduledoc """
  Default handler for AMQP connections. For this handler to work properly,
    one must include and start `:amqp` application with the config like

  ```elixir
  config :amqp,
    connections: [
      local_conn: [url: "amqp://guest:guest@localhost:5672"],
    ],
    channels: [
      chan_1: [connection: :local_conn]
    ]

  # Then you can access the connection/channel via `Rambla.Handlers.Amqp` as

  Rambla.Handlers.Amqp.publish(:chan_1, %{message: %{foo: 42}, exchange: "rambla"})
  ```
  """

  use Rambla.Handler

  @impl Rambla.Handler
  @doc false
  def handle_publish(
        %{message: message} = payload,
        %{connection: %{channel: name}, options: options}
      ) do
    options = options |> Map.new() |> Map.merge(Map.delete(payload, :message))
    {exchange, options} = Map.pop(options, :exchange, "")
    {declare?, options} = Map.pop(options, :declare?, false)
    {routing_key, options} = Map.pop(options, :routing_key, "")
    {channel_provider, options} = Map.pop(options, :channel_provider, AMQP.Application)
    {channel_publisher, options} = Map.pop(options, :channel_publisher, AMQP.Basic)

    with {:ok, json} <- Jason.encode(message),
         {:ok, chan} <- channel_provider.get_channel(name),
         :ok <- maybe_declare_exchange(declare?, chan, exchange),
         do: channel_publisher.publish(chan, exchange, routing_key, json, Map.to_list(options))
  end

  def handle_publish(callback, %{connection: %{channel: name}, options: options})
      when is_function(callback, 1) do
    channel_provider = Map.get(options, :channel_provider, AMQP.Application)

    with {:ok, chan} <- channel_provider.get_channel(name),
         do: callback.(chan)
  end

  def handle_publish(payload, state), do: handle_publish(%{message: payload}, state)

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
  Rambla.Handlers.Amqp.children_specs(
    connection_options: [exchange: "amq.direct"], count: 3)
  ```
  """
  def children_specs(options \\ []) do
    {connection_options, options} = Keyword.pop(options, :connection_options, [])

    connection_options =
      if is_function(connection_options, 1),
        do: connection_options,
        else: fn _ -> connection_options end

    for {name, params} <- Application.get_env(:amqp, :channels) do
      conn_opts = connection_options.(name)

      # make it `pool_options` if more options are needed
      {count, conn_opts} = Keyword.pop(conn_opts, :count)

      count
      |> is_nil()
      |> if(do: options, else: Keyword.put(options, :count, count))
      |> Keyword.put(:id, name)
      |> Keyword.put_new(:connection, %{channel: name, params: params})
      |> Keyword.put_new(:options, conn_opts)
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

  @doc false
  def child_spec(options) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [options]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  defp maybe_declare_exchange(false, _, _), do: :ok

  defp maybe_declare_exchange(type, chan, exchange) when is_atom(type),
    do: AMQP.Exchange.declare(chan, exchange, type)

  defp maybe_declare_exchange({type, options}, chan, exchange)
       when is_atom(type) and is_list(options),
       do: AMQP.Exchange.declare(chan, exchange, type, options)
end
