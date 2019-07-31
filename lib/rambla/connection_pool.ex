defmodule Rambla.ConnectionPool do
  @moduledoc """
  The dynamic supervisor for connection pools.

  Use `Rambla.ConnectionPool.start_pools/1` to add pools dynamically. It expects
  a keyword list of pools to add, each declared with the name of the worker _and_
  the options with the following keys:

  - `:type` the type of the worker; defaults to `:local`
  - `:name` the name of the worker; defaults to the module name
  - `:options` options to be passed to the worker initialization in `:poolboy`, like `[size: 5, max_overflow: 300]`
  - `:params` arguments to be passed to the worker during initialization
  """
  use DynamicSupervisor

  @notify_broadcast Application.get_env(:rambla, :notify_broadcast, true)

  if @notify_broadcast do
    use Envio.Publisher
  else
    defmacrop broadcast(_, _), do: :ok
  end

  @spec start_link(opts :: keyword) :: Supervisor.on_start()
  def start_link(opts \\ []),
    do: DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl DynamicSupervisor
  def init(opts), do: DynamicSupervisor.init(Keyword.put_new(opts, :strategy, :one_for_one))

  @spec start_pools(%{required(atom()) => keyword()}) :: [DynamicSupervisor.on_start_child()]
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

  @spec publish(type :: atom(), message :: map(), opts :: keyword()) ::
          Rambla.Connection.outcome()
  def publish(type, %{} = message, opts \\ []) do
    response = :poolboy.transaction(type, &GenServer.call(&1, {:publish, message, opts}))
    broadcast(type, %{message: message, response: response})
    response
  end

  @spec conn(type :: atom()) :: any()
  def conn(type),
    do: :poolboy.transaction(type, &GenServer.call(&1, :conn))
end
