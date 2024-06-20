defmodule Rambla.AMQPApplication do
  @moduledoc """
  Provides access to configured connections and channels.
  """

  use GenServer

  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_opts) do
    children = load_connections() ++ load_channels()

    opts = [
      strategy: :one_for_one,
      name: __MODULE__,
      max_restarts: length(children) * 2,
      max_seconds: 1
    ]

    Supervisor.start_link(children, opts)
  end

  defp load_connections do
    conn = Application.get_env(:rambla, :reliable_amqp)[:connection]
    conns = Application.get_env(:rambla, :reliable_amqp) |> Keyword.get(:connections, [])
    conns = if conn, do: conns ++ [default: conn], else: conns

    Enum.map(conns, fn {name, opts} ->
      arg = opts ++ [proc_name: name]
      id = AMQP.Application.Connection.get_server_name(name)
      Supervisor.child_spec({AMQP.Application.Connection, arg}, id: id)
    end)
  end

  defp load_channels do
    chan = Application.get_env(:rambla, :reliable_amqp)[:channel]
    chans = Application.get_env(:rambla, :reliable_amqp) |> Keyword.get(:channels, [])
    chans = if chan, do: chans ++ [default: chan], else: chans

    Enum.map(chans, fn {name, opts} ->
      arg = opts ++ [proc_name: name]
      id = AMQP.Application.Channel.get_server_name(name)
      Supervisor.child_spec({AMQP.Application.Channel, arg}, id: id)
    end)
  end
end
