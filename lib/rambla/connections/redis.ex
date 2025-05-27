defmodule Rambla.Redis do
  @moduledoc """
  Default connection implementation for 🔴 Redis.
  """

  @behaviour Rambla.Connection

  @impl Rambla.Connection
  def publish(%Rambla.Connection.Config{} = conn, message) when is_binary(message),
    do: publish(conn, Jason.decode!(message))

  @impl Rambla.Connection
  def publish(%Rambla.Connection.Config{conn: pid}, message)
      when is_map(message) or is_list(message) do
    to_pipeline = for {k, v} <- message, do: ["SET", k, v]
    apply(Redix, :pipeline, [pid, to_pipeline])
  end

  @impl Rambla.Connection
  if match?({:module, _}, Code.ensure_compiled(Redix)) do
    def connect(params) when is_list(params) do
      with :error <- Keyword.fetch(params, :host),
           do:
             raise(Rambla.Exceptions.Connection,
               source: __MODULE__,
               info: params,
               source: __MODULE__,
               reason: "inconsistent params",
               expected: "🔴 Redix configuration with :host key"
             )

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
    def connect(params) do
      raise(Rambla.Exceptions.Connection,
        source: __MODULE__,
        info: params,
        source: __MODULE__,
        reason: "missing dependencies",
        expected: "🔴 Redix must be added to `deps()`"
      )
    end
  end
end
