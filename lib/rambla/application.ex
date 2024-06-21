defmodule Rambla.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    Application.ensure_all_started(:telemetry)

    :logger.add_primary_filter(
      :ignore_rabbitmq_progress_reports,
      {&:logger_filters.domain/2, {:stop, :equal, [:progress]}}
    )

    children = [Rambla.ConnectionPool]

    opts = [strategy: :one_for_one, name: Rambla.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
