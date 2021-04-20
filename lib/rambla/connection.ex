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
  @type message :: binary() | Enum.t()

  @type messages :: [message()]

  defmodule Config do
    @moduledoc """
    The connection settings as requested by connection provider
    """

    @typedoc "The configuration of the real connection behind a pool"
    @type t :: %{
            __struct__: __MODULE__,
            conn: any(),
            opts: map(),
            defaults: map(),
            full_result: boolean()
          }

    defstruct conn: nil, opts: %{}, defaults: %{}, full_result: false
  end

  @typedoc "The connection information"
  @type t ::
          %{
            :__struct__ => Rambla.Connection,
            :conn => Config.t(),
            :conn_params => keyword(),
            :conn_type => atom(),
            :conn_pid => pid(),
            :opts => map(),
            :errors => [Rambla.Exception.t()]
          }

  @derive {Inspect, except: [:conn_params]}

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

  @reconnect_interval 100
  @keep_errors 2

  @doc """
  Accepts options for the underlying connection (those will be passed to `connect/1`.)
  """
  def start_link({conn_type, opts}),
    do: start_link(Keyword.put(opts, :conn_type, conn_type))

  def start_link(opts) when is_list(opts) do
    {[{:conn_type, conn_type}], opts} = Keyword.split(opts, [:conn_type])
    {name, opts} = Keyword.pop(opts, :singleton)

    params =
      case name do
        nil -> []
        mod when is_atom(mod) -> [name: mod]
      end

    GenServer.start_link(
      __MODULE__,
      %Rambla.Connection{
        conn_type: conn_type,
        conn_params: opts
      },
      params
    )
  end

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
          else: Process.link(pid)

        {:noreply, state}

      state ->
        safe_params = Keyword.drop(conn_params, [:password])

        Logger.error("""
        [🖇️] Failed to connect with params #{inspect(safe_params)}.
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
    conn = %Config{conn | opts: Map.merge(conn.opts, Map.new(opts))}

    {result, errors} =
      if conn.full_result do
        %{oks: oks, errors: errors} =
          Enum.reduce(messages, %{oks: [], errors: []}, fn message, acc ->
            case conn_type.publish(conn, message) do
              {:ok, result} -> %{acc | oks: [result | acc.oks]}
              {:error, reason} -> %{acc | errors: [reason | acc.errors]}
            end
          end)

        errors = :lists.reverse(errors)
        {%{oks: :lists.reverse(oks), errors: errors}, errors}
      else
        Enum.each(messages, &conn_type.publish(conn, &1))
        {:ok, []}
      end

    {:reply, result,
     %Rambla.Connection{state | errors: Enum.take(errors ++ state.errors, @keep_errors)}}
  end

  @impl GenServer
  def handle_call(
        {:publish, message, opts},
        _,
        %Rambla.Connection{conn_type: conn_type, conn: conn} = state
      )
      when is_binary(message) or is_map(message) do
    conn = %Config{conn | opts: Map.merge(conn.opts, Map.new(opts))}
    {:reply, conn_type.publish(conn, message), state}
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
