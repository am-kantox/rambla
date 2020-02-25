defmodule Rambla.Connection do
  @moduledoc """
  The default behaviour for publishers. The common use case would be the module
  implementing this behaviour opens a connection (and keep it opened,) and
  publishes messages as needed.
  """

  @typedoc "The response type; contains a status and a response from remote service"
  @type outcome :: {:ok | :error, Rambla.Exception.t() | any()}

  @typedoc "The connection information"
  @type t ::
          %{
            :__struct__ => Rambla.Connection,
            :conn => any(),
            :conn_type => atom(),
            :conn_params => keyword(),
            :conn_pid => pid(),
            :errors => [Rambla.Exception.t()]
          }

  defstruct conn: nil, conn_params: [], conn_type: nil, conn_pid: nil, errors: []

  @doc "Connects to the remote service and returns a connection object back"
  @callback connect(params :: keyword()) :: t()
  @doc "Publishes the message to the remote service using connection provided"
  @callback publish(conn :: any(), message :: map()) :: outcome()

  ##############################################################################

  use GenServer
  require Logger

  @reconnect_interval 10_000

  @doc """
  Accepts options for the underlying connection (those will be passed to `connect/1`.)
  """
  def start_link({conn_type, opts}),
    do:
      GenServer.start_link(__MODULE__, %Rambla.Connection{
        conn_type: conn_type,
        conn_params: opts
      })

  @doc false
  @impl GenServer
  def init(%Rambla.Connection{} = conn), do: {:ok, conn, {:continue, :start}}

  @doc false
  @impl GenServer
  def handle_continue(
        :start,
        %Rambla.Connection{conn_params: conn_params, conn_type: conn_type}
      ) do
    case conn_type.connect(conn_params) do
      %Rambla.Connection{conn: conn, conn_pid: pid, errors: []} = state when not is_nil(conn) ->
        if is_nil(pid),
          do: Logger.warn("[🖇️] No PID returned from connection. Monitoring is disabled."),
          else: Process.monitor(pid)

        {:noreply, state}

      state ->
        Logger.error("""
        [🖇️] Failed to connect with params #{inspect(conn_params)}.
            State: #{inspect(state)}.
            Retrying...
        """)

        Process.sleep(@reconnect_interval)
        {:noreply, state, {:continue, :start}}
    end
  end

  @doc false
  @impl GenServer
  def handle_call({:publish, message, opts}, _, %Rambla.Connection{conn: nil} = state),
    do: {:reply, {:error, {:no_connection, {message, opts}}}, state}

  @impl GenServer
  def handle_call(
        {:publish, %{} = message, opts},
        _,
        %Rambla.Connection{conn: conn, conn_type: conn_type} = state
      ),
      do:
        {:reply, conn_type.publish(Map.update(conn, :opts, opts, &Map.merge(&1, opts)), message),
         state}

  @doc false
  @impl GenServer
  def handle_call(:conn, _, %Rambla.Connection{} = state),
    do: {:reply, state, state}

  @doc false
  # Stop GenServer. Will be restarted by Supervisor.
  @impl GenServer
  def handle_info({:DOWN, _, :process, _pid, reason}, _),
    do: {:stop, {:connection_lost, reason}, nil}
end
