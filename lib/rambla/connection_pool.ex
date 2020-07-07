defmodule Rambla.ConnectionPool do
  @moduledoc false

  @with_telemetria :telemetria
                   |> Application.get_env(:applications, [])
                   |> Keyword.keys()
                   |> Enum.member?(:rambla) and
                     match?({:module, Telemetria}, Code.ensure_compiled(Telemetria))

  if @with_telemetria, do: use(Telemetria, action: :import)
  use DynamicSupervisor

  @spec start_link(opts :: keyword) :: Supervisor.on_start()
  def start_link(opts \\ []),
    do: DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl DynamicSupervisor
  def init(opts), do: DynamicSupervisor.init(Keyword.put_new(opts, :strategy, :one_for_one))

  @spec start_pools :: [DynamicSupervisor.on_start_child()]
  def start_pools do
    pools =
      for {k, v} <- Application.get_env(:rambla, :pools, []) do
        {options, params} =
          :rambla
          |> Application.get_env(k, [])
          |> Keyword.merge(v)
          |> Keyword.pop(:pool, [])

        {fix_type(k), params: params, options: options}
      end

    start_pools(pools)
  end

  @spec start_pools(%{required(atom()) => keyword()} | keyword()) :: [
          DynamicSupervisor.on_start_child()
        ]
  def start_pools(opts) do
    Enum.map(opts, fn {type, opts} ->
      with {options, opts} <- Keyword.pop(opts, :options, []),
           {worker_type, opts} <- Keyword.pop(opts, :type, :local),
           {worker_name, opts} <- Keyword.pop(opts, :name, type),
           {params, []} <- Keyword.pop(opts, :params, []) do
        worker =
          Keyword.merge(
            options,
            name: {worker_type, worker_name},
            worker_module: Rambla.Connection
          )

        child_spec = :poolboy.child_spec(Rambla.Connection, worker, {worker_name, params})
        DynamicSupervisor.start_child(Rambla.ConnectionPool, child_spec)
      end
    end)
  end

  @spec pools :: [{:undefined, pid() | :restarting, :worker | :supervisor, [:poolboy]}]
  def pools, do: DynamicSupervisor.which_children(Rambla.ConnectionPool)

  @spec publish(
          type :: atom(),
          messages :: Rambla.Connection.message() | Rambla.Connection.messages(),
          opts :: map() | keyword()
        ) ::
          Rambla.Connection.outcome() | Rambla.Connection.outcomes()
  def publish(type, messages, opts \\ %{})

  def publish(type, message, opts) when is_list(opts),
    do: publish(type, message, Map.new(opts))

  def publish(type, message, opts) when is_map(message) or is_binary(message) do
    case do_publish(type, [message], opts) do
      %{oks: [result], errors: []} -> {:ok, result}
      %{oks: [], errors: [reason]} -> {:error, reason}
      other -> other
    end
  end

  def publish(type, messages, opts) when is_list(messages),
    do: do_publish(type, messages, opts)

  if @with_telemetria, do: @telemetria(level: :info)

  @spec do_publish(type :: atom(), messages :: Rambla.Connection.messages(), opts :: map()) ::
          Rambla.Connection.outcome() | Rambla.Connection.outcomes()
  defp do_publish(type, messages, opts) when is_list(messages) do
    type = fix_type(type)
    timeout = messages |> length() |> timeout()

    :poolboy.transaction(
      type,
      &GenServer.call(&1, {:publish, messages, opts}, timeout),
      timeout
    )
  end

  @spec conn(type :: atom()) :: Rambla.Connection.Config.t()
  def conn(type),
    do: type |> fix_type() |> :poolboy.transaction(&GenServer.call(&1, :conn))

  @spec raw(type :: atom(), (pid() -> any())) :: any()
  def raw(type, f) when is_function(f, 1) do
    type
    |> fix_type()
    |> :poolboy.transaction(fn pid ->
      case GenServer.call(pid, :conn) do
        %Rambla.Connection{conn_pid: pid} -> {:ok, f.(pid)}
        _ -> {:error, :connection}
      end
    end)
  end

  @spec fix_type(k :: binary() | atom()) :: module()
  defp fix_type(k) when is_binary(k), do: String.to_existing_atom(k)

  defp fix_type(k) when is_atom(k) do
    case to_string(k) do
      "Elixir." <> _ -> k
      short_name -> Module.concat("Rambla", Macro.camelize(short_name))
    end
  end

  @spec timeout(count :: non_neg_integer()) :: timeout()
  defp timeout(count) when count < 10_000, do: 5_000
  defp timeout(count) when count < 20_000, do: 10_000
  defp timeout(count) when count < 25_000, do: 15_000
  defp timeout(count) when count < 30_000, do: 20_000
  defp timeout(_count), do: :infinity
end
