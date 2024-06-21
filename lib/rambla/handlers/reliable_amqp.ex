if :reliable_amqp in Rambla.services() do
  defmodule Rambla.Handlers.ReliableAmqp do
    @moduledoc """
    Default handler for reliable _AMQP_ connections. For this handler to work properly,
      one must include and start `:amqp` application with the config like

    ```elixir
    config :rambla,
      reliable_amqp: [
        connections: [
          reliable: [url: "amqp://guest:guest@localhost:5672"],
        ],
        channels: [
          reliable_channel: [connection: :reliable]
        ]
      ]

    # Then you can access the connection/channel via `Rambla.Handlers.ReliableAmqp` as

    Rambla.Handlers.ReliableAmqp.publish(:reliable_channel, %{message: %{foo: 42}, exchange: "rambla"})
    ```

    ---

    ### Known Options

    - `:exchange` (default: `""`)
    - `:declare?` (default: false)
    - `:routing_key`, (default: `""`)
    - `:channel_provider` (default: `Rambla.AMQPProducer`)
    - `:channel_publisher` (default: `AMQP.Basic`)
    """

    use Rambla.Handler

    alias AMQPHelpers.Reliability.Producer

    @impl Rambla.Handler
    @doc false
    def handle_publish(%{message: message}, options, %{connection: %{channel: name}}) do
      {exchange, options} = Map.pop(options, :exchange, "")
      {declare?, options} = Map.pop(options, :declare?, false)
      {routing_key, options} = Map.pop(options, :routing_key, "")
      {channel_provider, options} = Map.pop(options, :channel_provider, Rambla.AMQPProducer)
      {channel_publisher, options} = Map.pop(options, :channel_publisher, Producer)
      {preferred_format, options} = Map.pop(options, :preferred_format, :map)

      message = converter(preferred_format, message)

      options = Map.put(options, :message_id, Map.get(options, :message_id, UUID.uuid1()))

      with chan = channel_provider.get_channel(name),
           {:ok, json} <- Jason.encode(message),
           :ok <- maybe_declare_exchange(declare?, chan, exchange),
           do: channel_publisher.publish(chan, exchange, routing_key, json, Map.to_list(options))
    end

    def handle_publish(callback, options, %{connection: %{channel: name}})
        when is_function(callback, 1) do
      channel_provider = Map.get(options, :channel_provider, AMQP.Application)

      with {:ok, chan} <- channel_provider.get_channel(name),
           do: callback.(source: __MODULE__, destination: chan, options: options)
    end

    def handle_publish(payload, options, state),
      do: handle_publish(%{message: payload}, options, state)

    @impl Rambla.Handler
    @doc false
    def config, do: Application.get_env(:rambla, :reliable_amqp)

    defp maybe_declare_exchange(false, _, _), do: :ok

    defp maybe_declare_exchange(type, chan, exchange) when is_atom(type),
      do: AMQP.Exchange.declare(chan, exchange, type)

    defp maybe_declare_exchange({type, options}, chan, exchange)
         when is_atom(type) and is_list(options),
         do: AMQP.Exchange.declare(chan, exchange, type, options)
    
    @impl Rambla.Handler
    @doc false
    def external_servers(_id) do
      [Rambla.AMQPApplication, Rambla.AMQPProducerSupervisor]
    end
  end
end
