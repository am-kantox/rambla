defmodule Rambla.Channel do
  @moduledoc false

  @behaviour Rambla.Connection

  # , init: &Rambla.Channel.continue/0
  use Tarearbol.Pool, pool_size: 50

  # def continue, do: 0

  @impl Rambla.Connection
  defasynch publish(%Rambla.Connection.Config{} = _conn, message) do
    {:ok, message}
  end
end
