defmodule Rambla.Redis do
  @moduledoc """
  Default connection implementation for 🔴 Redis.
  """

  @with_redis match?({:module, _}, Code.ensure_compiled(Redix))

  @behaviour Rambla.Connection

  @impl Rambla.Connection

  def connect(params) when is_list(params) do
    if not @with_redis or is_nil(params[:host]),
      do:
        raise(Rambla.Exceptions.Connection,
          source: __MODULE__,
          info: params,
          reason: "🔴 Redix included and configured with :host key"
        )

    maybe_redis(params)
  end

  @impl Rambla.Connection
  def publish(%Rambla.Connection.Config{} = conn, message) when is_binary(message),
    do: publish(conn, Jason.decode!(message))

  @impl Rambla.Connection
  def publish(%Rambla.Connection.Config{conn: pid}, message)
      when is_map(message) or is_list(message) do
    to_pipeline = for {k, v} <- message, do: ["SET", k, v]
    apply(Redix, :pipeline, [pid, to_pipeline])
  end

  if @with_redis do
    defp maybe_redis(params) do
      params =
        params
        |> Keyword.get(:password, "")
        |> case do
          <<_::binary-size(1), _::binary>> -> params
          _ -> Keyword.delete(params, :password)
        end

      case Redix.start_link(params) do
        {:ok, pid} ->
          %Rambla.Connection{
            conn: %Rambla.Connection.Config{conn: pid},
            conn_type: __MODULE__,
            conn_pid: pid,
            conn_params: params,
            errors: []
          }

        error ->
          %Rambla.Connection{
            conn: %Rambla.Connection.Config{},
            conn_type: __MODULE__,
            conn_pid: nil,
            conn_params: params,
            errors: [error]
          }
      end
    end
  else
    defp maybe_redis(params) do
      error =
        Rambla.Exceptions.Connection.exception(
          source: __MODULE__,
          info: params,
          reason: "🔴 Redix should be explicitly included to use this functionality"
        )

      %Rambla.Connection{
        conn: %Rambla.Connection.Config{},
        conn_type: __MODULE__,
        conn_pid: nil,
        conn_params: params,
        errors: [error]
      }
    end
  end
end
