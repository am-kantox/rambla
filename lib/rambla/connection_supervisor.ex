defmodule Rambla.ConnectionSupervisor do
  @moduledoc false

  use Supervisor

  alias Rambla.{Channel, Connection}

  def start_link(opts) do
    {name, opts} = Keyword.split(opts, [:name])
    Supervisor.start_link(__MODULE__, opts, name)
  end

  @impl Supervisor
  def init(opts) do
    {channel_opts, connection_opts} = Keyword.split(opts, [:channel_options])

    children = [
      {Connection, connection_opts},
      {Channel, channel_opts}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
