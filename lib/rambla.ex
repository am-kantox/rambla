defmodule Rambla do
  @moduledoc """
  Interface for the message publishing through `Rambla`.

  `Rambla` maintains connection pools with a dynamix supervisor.
  It might be read from the config _or_ passed as a parameter in a call to
  `Rambla.start_pools/1`. The latter expects a keyword list of pools to add,
  each declared with the name of the worker _and_ the options with the following keys:

  - `:type` the type of the worker; defaults to `:local`
  - `:name` the name of the worker; defaults to the module name
  - `:options` options to be passed to the worker initialization in `:poolboy`, like `[size: 5, max_overflow: 300]`
  - `:params` arguments to be passed to the worker during initialization

  In the static configuration (through `config/env.exs`,) pool options might be given
  through `pool: keyword()` parameter.
  """

  @doc """
  Starts the pools configured in the `config.exs` / `releases.exs` file.

  This call is equivalent to `start_pools(Application.get_env(:rambla, :pools))`.
  """
  defdelegate start_pools(), to: Rambla.ConnectionPool
  @doc "Starts the pools as specified by options (`map()` or `keyword()`)"
  defdelegate start_pools(opts), to: Rambla.ConnectionPool

  @doc """
  Publishes the message to the target pool. The message structure depends on
  the destination. For `RabbitMQ` is might be whatever, for `Smtp` it expects
  to have `to:`, `subject:` and `body:` fields.
  """
  defdelegate publish(target, message), to: Rambla.ConnectionPool

  @doc """
  Publishes the message to the target pool, allowing additional options to be set.
  """
  defdelegate publish(target, message, opts), to: Rambla.ConnectionPool

  @doc """
  Executes any arbitrary function in the context of one of workers in the
  respective connection pool for the target.

  The function would receive a pid of the connection process.
  """
  defdelegate raw(target, f), to: Rambla.ConnectionPool
end
