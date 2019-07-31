defmodule Rambla.Redis do
  @moduledoc """
  Default connection implementation for 🔴 Redis.
  """
  @behaviour Rambla.Connection

  @impl Rambla.Connection
  def connect(params) when is_list(params) do
    if is_nil(params[:host]),
      do:
        raise(Rambla.Exceptions.Connection,
          value: params,
          expected: "🔴 configuration with :host key"
        )

    config = struct(Exredis.Config.Config, params)

    case Exredis.start_link(config) do
      {:ok, pid} ->
        %Rambla.Connection{
          conn: %{pid: pid},
          conn_type: __MODULE__,
          conn_pid: pid,
          conn_params: params,
          errors: []
        }

      error ->
        %Rambla.Connection{
          conn: nil,
          conn_type: __MODULE__,
          conn_pid: nil,
          conn_params: params,
          errors: [error]
        }
    end
  end

  @impl Rambla.Connection
  def publish(%{pid: pid}, message) when is_binary(message),
    do: publish(%{pid: pid}, Jason.decode!(message))

  @impl Rambla.Connection
  def publish(%{pid: pid}, message),
    do: {:ok, for({k, v} <- message, do: Exredis.Api.set(pid, k, v))}
end
