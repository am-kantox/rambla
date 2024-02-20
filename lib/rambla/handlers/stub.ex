defmodule Rambla.Handlers.Stub do
  @moduledoc """
  Default handler for _Stub_ testing doubles. Unlike `Rambla.Handlers.Mock`,
    this module might be used as a stub for remote service calls when 
    no expectation is to be defined, or when there is no room to define
    such an expectation (e. g. while application start.)

  By default it’d be simply return `:ok`.

  ```elixir
  config :rambla, stub: [
    connections: [stubbed: :conn],
    channels: [chan_0: [connection: :stubbed]]
  ]

  # Then you can access the connection/channel via `Rambla.Handlers.Stub` or
  #   implicitly via `Rambla` as

  Rambla.Handlers.Stub.publish(:chan_0, %{message: %{foo: 42}, serializer: Jason})
  Rambla.publish(:chan_0, %{message: %{foo: 42}, serializer: Jason})
  ```
  """

  use Rambla.Handler

  @callback on_publish(name :: atom(), message :: any(), options :: map()) :: :ok

  @impl Rambla.Handler
  @doc false
  def handle_publish(%{message: message} = payload, %{connection: %{channel: name}} = state) do
    options = extract_options(payload, state)
    {stub, options} = Map.pop(options, :stub, Rambla.Mocks.Stub)
    do_handle_publish(stub, name, message, options)
  end

  def handle_publish(callback, %{connection: %{channel: name}} = state)
      when is_function(callback, 1) do
    options = extract_options(%{}, state)
    callback.({name, options})
  end

  def handle_publish(payload, state), do: handle_publish(%{message: payload}, state)

  @impl Rambla.Handler
  @doc false
  def config, do: Application.get_env(:rambla, :stub)

  def do_handle_publish(stub, name, message, options) do
    stub.on_publish(name, message, options)
  end
end
