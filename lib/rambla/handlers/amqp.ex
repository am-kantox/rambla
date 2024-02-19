if :amqp in Rambla.services() do
  defmodule Rambla.Handlers.Amqp do
    @moduledoc """
    Default handler for _AMQP_ connections. For this handler to work properly,
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
          %{connection: %{channel: name}} = state
        ) do
      options = extract_options(payload, state)

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

    def handle_publish(callback, %{connection: %{channel: name}} = state)
        when is_function(callback, 1) do
      options = extract_options(%{}, state)
      channel_provider = Map.get(options, :channel_provider, AMQP.Application)

      with {:ok, chan} <- channel_provider.get_channel(name),
           do: callback.(chan)
    end

    def handle_publish(payload, state), do: handle_publish(%{message: payload}, state)

    @impl Rambla.Handler
    @doc false
    def config, do: Application.get_all_env(:amqp)

    defp maybe_declare_exchange(false, _, _), do: :ok

    defp maybe_declare_exchange(type, chan, exchange) when is_atom(type),
      do: AMQP.Exchange.declare(chan, exchange, type)

    defp maybe_declare_exchange({type, options}, chan, exchange)
         when is_atom(type) and is_list(options),
         do: AMQP.Exchange.declare(chan, exchange, type, options)
  end
end
