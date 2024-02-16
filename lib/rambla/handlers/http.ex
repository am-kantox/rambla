defmodule Rambla.Handlers.Http do
  @moduledoc """
  Default handler for HTTP connections.
  """

  @spec actor(binary() | map(), map()) :: {:ok, any()} | {:error, binary()}
  def actor(payload, state) do
    {:ok, {payload, state}}
  end
end
