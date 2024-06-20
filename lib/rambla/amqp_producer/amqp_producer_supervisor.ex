defmodule Rambla.AMQPProducerSupervisor do
  @moduledoc false

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children =
      Enum.map(
        channels(),
        &Supervisor.child_spec({Rambla.AMQPProducer, [channel: &1]}, id: &1)
      )

    Supervisor.init(children, strategy: :one_for_one)
  end

  @spec channels() :: [atom()]
  defp channels do
    :rambla
    |> Application.fetch_env!(:reliable_amqp)
    |> Keyword.get(:channels, [])
    |> Keyword.keys()
  end
end
