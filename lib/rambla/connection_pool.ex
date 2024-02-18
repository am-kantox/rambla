defmodule Rambla.ConnectionPool do
  @moduledoc false
  @moduledoc deprecated: "Use configuration instead"

  use Rambla.Telemetria
  use DynamicSupervisor

  @spec start_link(opts :: keyword) :: Supervisor.on_start()
  def start_link(opts \\ []),
    do: DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl DynamicSupervisor
  def init(opts), do: DynamicSupervisor.init(Keyword.put_new(opts, :strategy, :one_for_one))

  @mocks Application.compile_env(:rambla, :mocks, %{})

  @spec start_pools :: [
          [
            {:pool, DynamicSupervisor.on_start_child()}
            | {:synch, DynamicSupervisor.on_start_child()}
          ]
        ]

  def start_pools do
    pools =
      for {k, v} <- Application.get_env(:rambla, :pools, []) do
        {options, params} =
          :rambla
          |> Application.get_env(k, [])
          |> Keyword.merge(v)
          |> Keyword.pop(:options, [])

        {k, [params: params, options: options]}
      end

    start_pools(pools)
  end

  @spec start_pools(%{required(atom()) => keyword()} | keyword(), %{optional(atom()) => atom()}) ::
          [
            [
              {:pool, DynamicSupervisor.on_start_child()},
              {:synch, DynamicSupervisor.on_start_child()}
            ]
          ]
  def start_pools(opts, mocks \\ @mocks) do
    Enum.map(opts, fn {type, opts} ->
      opts =
        case opts do
          %{} = opts -> Map.to_list(opts)
          opts when is_list(opts) -> opts
        end

      {type, name} = fix_type(type, true, false)

      with {options, opts} <- Keyword.pop(opts, :options, []),
           {worker_type, opts} <- Keyword.pop(opts, :type, :local),
           {params, []} <- Keyword.pop(opts, :params, []) do
        module = type_to_module({type, name})

        worker =
          Keyword.merge(
            options,
            name: {worker_type, module},
            worker_module: Rambla.Connection
          )

        type = Map.get(mocks, type, type)
        child_spec = :poolboy.child_spec(Rambla.Connection, worker, {type, params})

        conn_opts =
          params
          |> Keyword.put(:singleton, Module.concat(module, "Synch"))
          |> Keyword.put(:conn_type, type)

        [
          pool: DynamicSupervisor.start_child(Rambla.ConnectionPool, child_spec),
          synch:
            DynamicSupervisor.start_child(Rambla.ConnectionPool, {Rambla.Connection, conn_opts})
        ]
      end
    end)
  end

  @spec pools :: [{:undefined, :restarting | pid(), :supervisor | :worker, atom()}]
  def pools, do: DynamicSupervisor.which_children(Rambla.ConnectionPool)

  @spec publish(
          type :: atom() | {atom(), any()},
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

  if Rambla.Telemetria.use?(), do: @telemetria(Rambla.Telemetria.apply_options())

  @spec do_publish(type :: atom(), messages :: Rambla.Connection.messages(), opts :: map()) ::
          Rambla.Connection.outcome() | Rambla.Connection.outcomes()
  defp do_publish(type, messages, opts) when is_list(messages) do
    timeout = messages |> length() |> timeout()

    :poolboy.transaction(
      fix_type(type),
      &GenServer.call(&1, {:publish, messages, opts}, timeout),
      timeout
    )
  end

  @spec publish_synch(
          type :: atom(),
          messages :: Rambla.Connection.message() | Rambla.Connection.messages(),
          opts :: map() | keyword()
        ) ::
          Rambla.Connection.outcome() | Rambla.Connection.outcomes()
  def publish_synch(type, message, opts \\ %{})

  def publish_synch(type, message, opts) when is_list(opts),
    do: publish_synch(type, message, Map.new(opts))

  def publish_synch(type, message, %{} = opts),
    do: do_publish_synch(type, message, opts)

  if Rambla.Telemetria.use?(), do: @telemetria(Rambla.Telemetria.apply_options())

  def do_publish_synch(type, message, %{} = opts) do
    {timeout, opts} = Map.pop(opts, :gen_server_timeout, 5000)

    singleton =
      type
      |> fix_type()
      |> Module.concat("Synch")

    GenServer.call(singleton, {:publish, message, opts}, timeout)
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

  @spec fix_type(atom() | {atom(), atom() | binary()}, boolean(), boolean()) ::
          {module(), any()} | module()
  defp fix_type(name, retry? \\ true, module? \\ true)

  defp fix_type({type, name}, retry?, module?) when is_atom(type) do
    type =
      case {retry?, Code.ensure_loaded?(type)} do
        {_, true} ->
          {type, name}

        {true, _} ->
          fix_type(type_to_module({"Rambla", type}), false, false)

        _ ->
          raise Rambla.Exceptions.Unknown,
            source: __MODULE__,
            reason: "Unknown type: " <> inspect({type, name})
      end

    if module?, do: type_to_module(type), else: type
  end

  defp fix_type({type}, retry?, module?) when is_atom(type),
    do: fix_type(type, retry?, module?)

  defp fix_type(type, retry?, module?) when is_atom(type),
    do: fix_type({type, :default}, retry?, module?)

  @spec type_to_module({atom(), atom() | binary()} | atom() | binary()) :: module()
  defp type_to_module(type) when is_atom(type) or is_binary(type),
    do: Module.concat([type |> to_string() |> Macro.camelize()])

  defp type_to_module({type, name})
       when (is_binary(type) or is_atom(type)) and (is_binary(name) or is_atom(name)),
       do: [type, name] |> Enum.map(&type_to_module/1) |> Module.concat()

  @spec timeout(count :: non_neg_integer()) :: timeout()
  defp timeout(count) when count < 10_000, do: 10_000
  defp timeout(count) when count < 20_000, do: 20_000
  defp timeout(count) when count < 25_000, do: 25_000
  defp timeout(count) when count < 30_000, do: 30_000
  defp timeout(_count), do: :infinity
end
