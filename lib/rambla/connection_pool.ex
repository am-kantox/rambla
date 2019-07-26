defmodule Rambla.ConnectionPool do
  use DynamicSupervisor

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

  @spec pools :: [{:undefined, pid() | :restarting, :worker | :supervisor, :supervisor.modules()}]
  def pools, do: DynamicSupervisor.which_children(Rambla.ConnectionPool)

  @spec publish(type :: atom(), message: map(), opts :: keyword()) :: Rambla.Connection.outcome()
  def publish(type, %{} = message, opts \\ []),
    do: :poolboy.transaction(type, &GenServer.call(&1, {:publish, message, opts}))
end
