defmodule Rambla.Redis do
  @moduledoc """
  Default connection implementation for 🔴 Redis.
  """

  @with_exredis match?({:module, _}, Code.ensure_compiled(Exredis))

  @behaviour Rambla.Connection

  @impl Rambla.Connection

  def connect(params) when is_list(params) do
    if not @with_exredis or is_nil(params[:host]),
      do:
        raise(Rambla.Exceptions.Connection,
          source: __MODULE__,
          info: params,
          reason: "🔴 Exredis included and configured with :host key"
        )

    maybe_exredis(params)
  end

  @impl Rambla.Connection
  def publish(%{pid: pid}, message) when is_binary(message),
    do: publish(%{pid: pid}, Jason.decode!(message))

  @impl Rambla.Connection
  def publish(%{pid: pid}, message),
    do: {:ok, for({k, v} <- message, do: apply(Exredis.Api, :set, [pid, k, v]))}

  if @with_exredis do
    defp maybe_exredis(params) do
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
  else
    defp maybe_exredis(params) do
      error =
        Rambla.Exceptions.Connection.exception(
          source: __MODULE__,
          info: params,
          reason: "🔴 Exredis should be explicitly included to use this functionality"
        )

      %Rambla.Connection{
        conn: nil,
        conn_type: __MODULE__,
        conn_pid: nil,
        conn_params: params,
        errors: [error]
      }
    end
  end
end
