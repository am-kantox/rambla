defmodule Rambla.Connection do
  @moduledoc """
  The default behaviour for publishers. The common use case would be the module
  implementing this behaviour opens a connection (and keep it opened,) and
  publishes messages as needed.
  """

  @typedoc """
  The response type for the single request.
  Contains a status and a response from remote service
  """
  @type outcome :: {:ok | :error, Rambla.Exception.t() | any()}

  @typedoc """
  The response type for the bulk request.
  Contains a status and a response from remote service
  """
  @type outcomes :: %{oks: [any()], errors: [Rambla.Exception.t()]}

  @typedoc "The accepted type of the message to be published"
  @type message :: binary() | map()

  @type messages :: [message()]

  @typedoc "The connection information"
  @type t ::
          %{
            :__struct__ => Rambla.Connection,
            :conn => any(),
            :conn_params => keyword(),
            :conn_type => atom(),
            :conn_pid => pid(),
            :opts => map(),
            :errors => [Rambla.Exception.t()]
          }

  defstruct conn: nil,
            conn_params: [],
            conn_type: nil,
            conn_pid: nil,
            opts: %{},
            errors: []

  @doc "Connects to the remote service and returns a connection object back"
  @callback connect(params :: keyword()) :: t()
  @doc "Publishes the message to the remote service using connection provided"
  @callback publish(conn :: any(), message :: message()) :: outcome()

  ##############################################################################

  use GenServer
  require Logger

  @reconnect_interval 10_000
  @keep_errors 20

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
  def handle_call({:publish, messages, opts}, _, %Rambla.Connection{conn: nil} = state),
    do: {:reply, {:error, {:no_connection, {messages, opts}}}, state}

  @impl GenServer
  def handle_call({:publish, [], opts}, _, state),
    do: {:reply, {:error, :no_data, {[], opts}}, state}

  @impl GenServer
  def handle_call(
        {:publish, messages, opts},
        _,
        %Rambla.Connection{conn_type: conn_type, conn: conn} = state
      )
      when is_list(messages) do
    opts = Map.update(conn, :opts, opts, &Map.merge(&1, opts))
    {full_result, opts} = Map.pop(opts, :full_result, true)

    {result, errors} =
      if full_result do
        %{oks: oks, errors: errors} =
          Enum.reduce(messages, %{oks: [], errors: []}, fn message, acc ->
            case conn_type.publish(opts, message) do
              {:ok, result} -> %{acc | oks: [result | acc.oks]}
              {:error, reason} -> %{acc | errors: [reason | acc.errors]}
            end
          end)

        errors = :lists.reverse(errors)
        {%{oks: :lists.reverse(oks), errors: errors}, errors}
      else
        Enum.each(messages, &conn_type.publish(opts, &1))
        {:ok, []}
      end

    {:reply, result,
     %Rambla.Connection{state | errors: Enum.take(errors ++ state.errors, @keep_errors)}}
  end

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
