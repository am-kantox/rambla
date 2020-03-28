defmodule Mix.Tasks.Rambla.Rabbit.Queue do
  @shortdoc "Operations with queues in RabbitMQ"
  @moduledoc since: "0.6.0"
  @moduledoc """
  Mix task to deal with queues in the target RabbitMQ.

  This is helpful to orchestrate target RabbitMQ when deploying
  to docker. Allows to create, delete, purge and query status of
  the queue.

  Loads the setting from `config :rambla, :amqp` if no connection
  is provided in parameters.

  ## Command line options
    * -c - the connection string
    * -o - the list of options without spaces, separated by comma

  ## Options

  ### Options for `create`
    * `durable` - If set, keeps the Queue between restarts
      of the broker. Defaults to false.
    * `auto_delete` - If set, deletes the Queue once all
      subscribers disconnect. Defaults to false.
    * `exclusive` - If set, only one subscriber can consume
      from the Queue. Defaults to false.
    * `passive` - If set, raises an error unless the queue
      already exists. Defaults to false.
    * `no_wait` - If set, the declare operation is asynchronous.
      Defaults to false.
    * `arguments` - A list of arguments to pass when declaring
      (of type AMQP.arguments/0). See the README for more information. Defaults to [].

  ### Options for `delete`

    * `if_unused` - If set, the server will only delete the queue
      if it has no consumers. If the queue has consumers, it’s
      not deleted and an error is returned.
    * `if_empty` - If set, the server will only delete the queue
      if it has no messages.
    * `no_wait` - If set, the delete operation is asynchronous.

  """

  use Mix.Task

  @switches [
    connection: :string,
    options: :string
  ]
  @commands ~w|declare create delete purge status|

  require Logger

  @impl Mix.Task
  @doc false
  def run([command, name | args]) when command in @commands do
    Logger.configure(level: :error)
    Process.flag(:trap_exit, true)

    {opts, _} =
      OptionParser.parse!(args, aliases: [o: :options, c: :connection], strict: @switches)

    connection =
      case Keyword.get(opts, :connection, Application.get_env(:rambla, :amqp)) do
        uri when is_binary(uri) ->
          uri

        params when is_list(params) ->
          port = if params[:port], do: ":#{params[:port]}", else: ""
          "amqp://#{params[:username]}:#{params[:password]}@#{params[:host]}#{port}"

        nil ->
          Mix.raise(
            "The connection string must be either passed as -c option or set in `config :rambla, :amqp`"
          )
      end

    with {:ok, conn} <- AMQP.Connection.open(connection),
         {:ok, chan} = AMQP.Channel.open(conn),
         opts =
           opts
           |> Keyword.get(:options, "")
           |> String.replace(~r/:(?=\S)/, ": "),
         {opts, _} <- Code.eval_string("[" <> opts <> "]"),
         {:ok, result} <- do_command(chan, String.to_atom(command), name, opts) do
      Mix.shell().info("Success. Results are: " <> inspect(result))
    else
      amqp_base_error ->
        Mix.raise("Cannot execute command on target. Error:\n" <> inspect(amqp_base_error))
    end
  end

  @doc false
  def run(_),
    do:
      Mix.raise(
        "Usage: mix rambla.rabbit.queue (" <> Enum.join(@commands, "|") <> ") name [opts]"
      )

  @spec do_command(
          chan :: AMQP.Channel.t(),
          command :: atom(),
          name :: binary(),
          opts :: keyword()
        ) :: {:ok, binary()} | {:error, any()}
  defp do_command(chan, :create, name, opts),
    do: do_command(chan, :declare, name, opts)

  defp do_command(chan, command, name, opts) do
    AMQP.Queue.__info__(:functions)
    |> Keyword.get_values(command)
    |> :lists.reverse()
    |> case do
      [3 | _] -> {:ok, apply(AMQP.Queue, command, [chan, name, opts])}
      [2 | _] -> {:ok, apply(AMQP.Queue, command, [chan, name])}
      _other -> {:error, {:unknown_command, command}}
    end
  end
end
