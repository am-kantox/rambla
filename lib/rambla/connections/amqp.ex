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
    to be passed as is to call to `AMQP.Basic.publish/5`

  ---

  Since `v0.6.0` provides two `mix` tasks:

  - `mix rambla.rabbit.exchange` Operations with exchanges in RabbitMQ
  - `mix rambla.rabbit.queue`    Operations with queues in RabbitMQ

  Tasks support arguments to be passed to RabbitMQ instance. Usage example:

  ```
  mix rambla.rabbit.queue declare foo -o durable:true
  ```

  """

  defmodule ChannelPool do
    @moduledoc false

    @spec publish(Rambla.Connection.Config.t(), binary() | map() | list()) :: {:ok, any()}
    def publish(%Rambla.Connection.Config{conn: conn} = cfg, message) do
      do_publish(conn, cfg, message)
    end

    defp do_publish(
           conn,
           %Rambla.Connection.Config{conn: conn, chan: chan, opts: opts},
           message
         ) do
      message =
        case message do
          message when is_binary(message) -> message
          %{} = message -> Jason.encode!(message)
          [{_, _} | _] = message -> message |> Map.new() |> Jason.encode!()
          message -> inspect(message)
        end

      with %{exchange: exchange} <- opts,
           declare? <- Map.get(opts, :declare?, true),
           if(declare?, do: apply(AMQP.Exchange, :declare, [chan, exchange])),
           :ok <- queue!(chan, opts) do
        apply(AMQP.Basic, :publish, [
          chan,
          exchange,
          Map.get(opts, :routing_key, ""),
          message,
          Map.get(opts, :options, [])
        ])

        {:ok, message}
      else
        error -> {:error, error}
      end
    end

    @spec queue!(chan :: AMQP.Channel.t(), map()) :: :ok
    defp queue!(chan, %{queue: queue, exchange: exchange}) do
      with {:ok, %{consumer_count: _, message_count: _, queue: ^queue}} <-
             apply(AMQP.Queue, :declare, [chan, queue]),
           do: apply(AMQP.Queue, :bind, [chan, queue, exchange])
    end

    defp queue!(_, %{exchange: _exchange}), do: :ok
  end

  @with_amqp match?({:module, _}, Code.ensure_compiled(AMQP.Channel))

  @behaviour Rambla.Connection

  @impl Rambla.Connection
  def connect(params) when is_list(params) do
    if not @with_amqp or is_nil(params[:host]),
      do:
        raise(Rambla.Exceptions.Connection,
          value: params,
          source: __MODULE__,
          reason: "inconsistent params",
          expected: "🐰 configuration with :host key"
        )

    maybe_amqp(params)
  end

  @impl Rambla.Connection
  def publish(%Rambla.Connection.Config{} = conn, message)
      when is_binary(message) or is_list(message) or is_map(message),
      do: ChannelPool.publish(conn, message)

  if @with_amqp do
    defp maybe_amqp(params) do
      with {:ok, conn} <- AMQP.Connection.open(params),
           {:ok, chan} <- AMQP.Channel.open(conn) do
        Process.link(conn.pid)

        %Rambla.Connection{
          conn: %Rambla.Connection.Config{conn: conn, chan: chan},
          conn_type: __MODULE__,
          conn_pid: conn.pid,
          conn_params: params,
          errors: []
        }
      else
        error ->
          %Rambla.Connection{
            conn: %Rambla.Connection.Config{},
            conn_type: __MODULE__,
            conn_pid: nil,
            conn_params: params,
            errors: [error]
          }
      end
    end
  else
    defp maybe_amqp(params) do
      error =
        Rambla.Exceptions.Connection.exception(
          source: __MODULE__,
          info: params,
          reason: "🐰 AMQP should be explicitly included to use this functionality"
        )

      %Rambla.Connection{
        conn: %Rambla.Connection.Config{},
        conn_type: __MODULE__,
        conn_pid: nil,
        conn_params: params,
        errors: [error]
      }
    end
  end
end
