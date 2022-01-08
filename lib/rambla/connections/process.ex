defmodule Rambla.Process do
  @moduledoc """
  Default connection implementation for 🕸️ Process message callback.

  For instance, this call would send a message back to the calling process.

  ```elixir
  Rambla.publish(
    Rambla.Process,
    %{method: :post, body: %{message: "I ❤ HTTP"}}
  }
  ```
  """
  @behaviour Rambla.Connection

  @impl Rambla.Connection
  def connect(params) when is_list(params) do
    # TODO shall we monitor the calling process here?

    {process, params} = Keyword.pop(params, :callback, self())

    %Rambla.Connection{
      conn: %Rambla.Connection.Config{conn: process, opts: Map.new(params)},
      conn_type: __MODULE__,
      conn_pid: self()
    }
  end

  @impl Rambla.Connection
  def publish(
        %Rambla.Connection.Config{conn: process, opts: payload},
        %{__action__: :call} = message
      ),
      do: GenServer.call(process, cleanup(message, payload))

  @impl Rambla.Connection
  def publish(
        %Rambla.Connection.Config{conn: process, opts: payload},
        %{__action__: :cast} = message
      ),
      do: GenServer.cast(process, cleanup(message, payload))

  @impl Rambla.Connection
  def publish(%Rambla.Connection.Config{opts: payload}, %{__action__: pid} = message)
      when is_pid(pid),
      do: send(pid, cleanup(message, payload))

  @impl Rambla.Connection
  def publish(%Rambla.Connection.Config{conn: process} = conn, %{__action__: :info} = message),
    do: publish(conn, Map.put(message, :__action__, process))

  @impl Rambla.Connection
  def publish(%Rambla.Connection.Config{} = conn, message),
    do: publish(conn, Map.put(message, :__action__, :info))

  @spec cleanup(map(), any()) :: map()
  defp cleanup(message, payload),
    do: %{message: Map.delete(message, :__action__), payload: payload}
end
