defmodule Rambla.Handlers.Amqp do
  @moduledoc """
  Default handler for AMQP connections.

  ```elixir
  config :amqp,
    connections: [
      local_conn: [url: "amqp://guest:guest@localhost:5672"],
    ],
    channels: [
      chan_1: [connection: :local_conn]
    ]

  # Then you can access the connection/channel via AMQP.Application.

  {:ok, chan} = AMQP.Application.get_channel(:mychan)
  :ok = AMQP.Basic.publish(chan, "", "", "Hello")
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

    with {:ok, json} <- Jason.encode(message),
         {:ok, chan} <- AMQP.Application.get_channel(name),
         :ok <- maybe_declare_exchange(declare?, chan, exchange),
         do: AMQP.Basic.publish(chan, exchange, routing_key, json, Map.to_list(options))
  end

  def handle_publish(callback, %{connection: %{channel: name}}) when is_function(callback, 1) do
    with {:ok, chan} <- AMQP.Application.get_channel(name),
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
      options
      |> Keyword.put(:id, name)
      |> Keyword.put_new(:connection, %{channel: name, params: params})
      |> Keyword.put_new(:options, connection_options.(name))
      |> child_spec()
    end
  end

  defp maybe_declare_exchange(false, _, _), do: :ok

  defp maybe_declare_exchange(type, chan, exchange) when is_atom(type),
    do: AMQP.Exchange.declare(chan, exchange, type)

  defp maybe_declare_exchange({type, options}, chan, exchange)
       when is_atom(type) and is_list(options),
       do: AMQP.Exchange.declare(chan, exchange, type, options)
end
