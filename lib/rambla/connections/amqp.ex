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
    @amqp_pool_size Application.get_env(:rambla, :amqp_pool_size, 32)
    use Tarearbol.Pool, pool_size: @amqp_pool_size, pickup: :hashring

    @spec publish(%Rambla.Connection.Config{}, binary() | map() | list()) ::
            {:ok | :replace, Rambla.Connection.Config.t()}
    def publish(%Rambla.Connection.Config{conn: conn} = cfg, message) do
      id = Enum.random(1..workers_slice())
      do_publish({id, conn}, cfg, message)
    end

    defsynch do_publish(
               {id, conn},
               %Rambla.Connection.Config{conn: conn, opts: opts} = cfg,
               message
             ) do
      message =
        case message do
          message when is_binary(message) -> message
          %{} = message -> Jason.encode!(message)
          [{_, _} | _] = message -> message |> Map.new() |> Jason.encode!()
          message -> inspect(message)
        end

      {_, %{chan: %{__struct__: AMQP.Channel} = chan}} =
        reply =
        case payload!() do
          %{conn: ^conn, chan: %{__struct__: AMQP.Channel}} = cfg ->
            {:ok, cfg}

          %{} = cfg ->
            if not is_nil(cfg[:chan]), do: apply(AMQP.Channel, :close, [cfg[:chan]])
            {:replace, %{conn: conn, chan: AMQP.Channel |> apply(:open, [conn]) |> elem(1)}}
        end

      with %{exchange: exchange} <- opts,
           declare? <- Map.get(opts, :declare?, true),
           if(declare?, do: apply(AMQP.Exchange, :declare, [chan, exchange])),
           :ok <- queue!(chan, opts),
           do:
             apply(AMQP.Basic, :publish, [
               chan,
               exchange,
               Map.get(opts, :routing_key, ""),
               message,
               Map.get(opts, :options, [])
             ])

      reply
    end

    @spec queue!(chan :: AMQP.Channel.t(), map()) :: :ok
    defp queue!(chan, %{queue: queue, exchange: exchange}) do
      with {:ok, %{consumer_count: _, message_count: _, queue: ^queue}} <-
             apply(AMQP.Queue, :declare, [chan, queue]),
           do: apply(AMQP.Queue, :bind, [chan, queue, exchange])
    end

    defp queue!(_, %{exchange: _exchange}), do: :ok

    @spec workers_slice :: pos_integer()
    defp workers_slice,
      do: Application.get_env(:rambla, __MODULE__) || invalidate_workers_slice()

    @spec invalidate_workers_slice :: pos_integer()
    defp invalidate_workers_slice do
      poolboy =
        Rambla.ConnectionPool
        |> DynamicSupervisor.which_children()
        |> Enum.reduce_while(nil, fn
          {_, pid, :worker, [:poolboy]}, nil -> {:halt, pid}
          _, nil -> {:cont, nil}
        end)

      with pid when is_pid(pid) <- poolboy,
           {:ready, num, _, _} when num >= 0 <- :poolboy.status(pid) do
        num = div(@amqp_pool_size, num + 1)
        Application.put_env(:rambla, __MODULE__, num)
        num
      else
        _ -> @amqp_pool_size
      end
    end
  end

  @with_amqp match?({:module, _}, Code.ensure_compiled(AMQP.Channel))

  @behaviour Rambla.Connection

  @impl Rambla.Connection
  def connect(params) when is_list(params) do
    if not @with_amqp or is_nil(params[:host]),
      do:
        raise(Rambla.Exceptions.Connection,
          value: params,
          expected: "🐰 configuration with :host key"
        )

    case ChannelPool.start_link() do
      {:ok, pool} -> Process.link(pool)
      {:error, {:already_started, pool}} -> Process.link(pool)
    end

    maybe_amqp(params)
  end

  @impl Rambla.Connection
  def publish(%Rambla.Connection.Config{} = conn, message)
      when is_binary(message) or is_list(message) or is_map(message),
      do: ChannelPool.publish(conn, message)

  if @with_amqp do
    defp maybe_amqp(params) do
      case AMQP.Connection.open(params) do
        {:ok, conn} ->
          Process.link(conn.pid)

          %Rambla.Connection{
            conn: %Rambla.Connection.Config{conn: conn},
            conn_type: __MODULE__,
            conn_pid: conn.pid,
            conn_params: params,
            errors: []
          }

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
