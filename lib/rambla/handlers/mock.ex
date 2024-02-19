if :mock in Rambla.services() do
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

    # Then you can access the connection/channel via `Rambla.Handlers.Amqp` as

    Rambla.Handlers.Mock.publish(:chan_1, %{message: %{foo: 42}, serializer: Jason})
    ```
    """

    use Rambla.Handler

    @callback on_publish(name :: atom(), message :: any(), options :: map()) :: :ok

    @impl Rambla.Handler
    @doc false
    def handle_publish(%{message: message} = payload, %{connection: %{channel: name}} = state) do
      options = extract_options(payload, state)
      {mock, options} = Map.pop(options, :mock, Rambla.Mocks.Generic)
      do_handle_publish(mock, name, message, options)
    end

    def handle_publish(callback, %{connection: %{channel: name}} = state)
        when is_function(callback, 1) do
      options = extract_options(%{}, state)
      callback.({name, options})
    end

    def handle_publish(payload, state), do: handle_publish(%{message: payload}, state)

    @impl Rambla.Handler
    @doc false
    def config, do: Application.get_env(:rambla, :mock)

    def do_handle_publish(mock, name, message, options) do
      mock.on_publish(name, message, options)
    end
  end
end
