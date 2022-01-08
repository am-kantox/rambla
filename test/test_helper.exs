defmodule Rambla.Foo do
  @moduledoc false
  @behaviour Rambla.Connection

  @impl Rambla.Connection
  def connect(params) when is_list(params), do: %Rambla.Connection{}

  @impl Rambla.Connection
  def publish(%Rambla.Connection.Config{}, message), do: message
end

ExUnit.start()
