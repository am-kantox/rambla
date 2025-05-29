if :mock in Rambla.services() do
  Code.ensure_compiled!(Mox)

  defmodule Rambla.Handlers.Mock do
    @moduledoc """
    Default handler for _Mock_ testing doubles. 

    Normally, the `test.exs` config would have included all the channels
      under `config :rambla, mock: […]` key. This would allow testing actual
      interactions using `Mox` library.

    By default it’d be simply send the message back to the caller.

    ```elixir
    config :rambla, mock: [
      connections: [mocked: :conn],
      channels: [chan_0: [connection: :mocked]]
    ]

    # Then you can access the connection/channel explicitly via `Rambla.Handlers.Mock`
    #   or implicitly via `Rambla` as

    Rambla.publish(:chan_0, %{message: %{foo: 42}, serializer: Jason})
    Rambla.Handlers.Mock.publish(:chan_0, %{message: %{foo: 42}, serializer: Jason})
    ```
    """

    use Rambla.Handler

    @callback on_publish(name :: atom(), message :: any(), options :: map()) ::
                Rambla.Handler.resolution()

    @impl Rambla.Handler
    @doc false
    def handle_publish(messages, options, state) when is_list(messages),
      do: Enum.each(messages, &handle_publish(&1, options, state))

    def handle_publish(%{message: message}, options, %{connection: %{channel: name}}) do
      {mock, options} = Map.pop(options, :mock, Rambla.Mocks.Generic)
      {preferred_format, options} = Map.pop(options, :preferred_format, :none)

      do_handle_publish(mock, name, converter(preferred_format, message), options)
    end

    def handle_publish(callback, options, %{connection: %{channel: name}})
        when is_function(callback, 1) do
      callback.(source: __MODULE__, destination: name, options: options)
    end

    def handle_publish(payload, options, state),
      do: handle_publish(%{message: payload}, options, state)

    @impl Rambla.Handler
    @doc false
    def config, do: Application.get_env(:rambla, :mock)

    def do_handle_publish(mock, name, message, options) do
      mock.on_publish(name, message, options)
    end
  end
end
