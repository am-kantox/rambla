defmodule Rambla.Amqp do
  @moduledoc """
  Default connection implementation for 🐰 Rabbit.
  """
  @behaviour Rambla.Connection

  #  rabbit = Keyword.get(state, :conn, Application.get_env(:eventory, :amqp, []))

  @impl Rambla.Connection
  def connect(params) when is_list(params) do
    if is_nil(params[:host]),
      do:
        raise(Rambla.Exceptions.Connection,
          value: params,
          expected: "🐰 configuration with :host key"
        )

    with {:ok, conn} <- AMQP.Connection.open(params),
         {:ok, chan} <- AMQP.Channel.open(conn) do
      %Rambla.Connection{
        conn: %{conn: conn, chan: chan},
        conn_type: __MODULE__,
        conn_pid: conn.pid,
        conn_params: params,
        errors: []
      }
    else
      error ->
        %Rambla.Connection{
          conn: nil,
          conn_type: __MODULE__,
          conn_pid: nil,
          conn_params: params,
          errors: [error]
        }
    end
  end

  @impl Rambla.Connection
  def publish(%{conn: conn, chan: chan, opts: opts}, message) when is_binary(message),
    do: publish(%{conn: conn, chan: chan, opts: opts}, Jason.decode!(message))

  @impl Rambla.Connection
  def publish(%{conn: _conn, chan: chan, opts: opts}, message)
      when is_map(opts) and is_map(message) do
    with %{queue: queue, exchange: exchange} <- opts,
         {:ok, %{consumer_count: _, message_count: _, queue: ^queue}} <-
           AMQP.Queue.declare(chan, queue),
         :ok <- AMQP.Exchange.declare(chan, exchange),
         :ok <- AMQP.Queue.bind(chan, queue, exchange),
         :ok <-
           AMQP.Basic.publish(
             chan,
             exchange,
             Map.get(opts, :routing_key, ""),
             Jason.encode!(message),
             Map.get(opts, :options, [])
           ) do
      {:ok, message}
    else
      error -> {:error, error}
    end
  end
end
