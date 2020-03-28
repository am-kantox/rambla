defmodule Rambla.Amqp do
  @moduledoc """
  Default connection implementation for 🐰 Rabbit.

  `publish/2` accepts the following options:

  - `exchange` [`binary()`, **mandatory**] the exchange to publish to
  - `queue` [`binary()`, **optional**] if passed, the queue will be created
    and bound to the exchange; it’s slowing down publishing, but safer
    for the cold RebbatMQ installation
  - `declare?`[`boolean()`, **optional**, _default_: `true`] if false
    is passed, the exchange would not be declared; use it if the exchange
    already surely exists to speed up the publishing
  - `routing_key` [`binary()`, **optional**, _default_: `""`] if passed,
    used as a routing key
  - `options` [`keyword()`, **optional**, _default_: `[]`] the options
    to be passe as is to call to `AMQP.Basic.publish/5`

  ---

  Since `v0.6.0` provides two `mix` tasks:

  - `mix rambla.rabbit.exchange` Operations with exchanges in RabbitMQ
  - `mix rambla.rabbit.queue`    Operations with queues in RabbitMQ

  Tasks support arguments to be passed to RabbitMQ instance. Usage example:

  ```
  mix rambla.rabbit.queue declare foo -o durable:true
  ```

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
    with %{exchange: exchange} <- opts,
         declare? <- Map.get(opts, :declare?, true),
         if(declare?, do: AMQP.Exchange.declare(chan, exchange)),
         :ok <- queue!(chan, opts),
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

  @spec queue!(chan :: AMQP.Channel.t(), map()) :: :ok
  defp queue!(chan, %{queue: queue, exchange: exchange}) do
    with {:ok, %{consumer_count: _, message_count: _, queue: ^queue}} <-
           AMQP.Queue.declare(chan, queue),
         do: AMQP.Queue.bind(chan, queue, exchange)
  end

  defp queue!(_, %{exchange: _exchange}), do: :ok
end
