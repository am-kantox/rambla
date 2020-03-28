defmodule Mix.Tasks.Rambla.Rabbit.Exchange do
  @shortdoc "Operations with exchanges in RabbitMQ"
  @moduledoc since: "0.6.0"
  @moduledoc """
  Mix task to deal with exchanges in the target RabbitMQ.

  This is helpful to orchestrate target RabbitMQ when deploying
  to docker. Allows to create and delete the exchange.

  Loads the setting from `config :rambla, :amqp` if no connection
  is provided in parameters.

  ## Command line options
    * -c - the connection string
    * -o - the list of options without spaces, separated by comma

  ## Options

  ### Options for `create`
    * **`type`** - One of four possible values below. Defaults to `:direct`.
      * `direct`
      * `fanout`
      * `topic`
      * `headers`
    * `durable` - If set, keeps the Exchange between restarts of the broker;
    * `auto_delete` - If set, deletes the Exchange once all queues
      unbind from it;
    * `passive` - If set, returns an error if the Exchange does not
      already exist;
    * `internal` - If set, the exchange may not be used directly by
      publishers, but only when bound to other exchanges. Internal exchanges are used to construct wiring that is not visible to applications.
    * `no_wait` - If set, the declare operation is asynchronous.
      Defaults to false.
    * `arguments` - A list of arguments to pass when declaring
      (of type AMQP.arguments/0). See the README for more information. Defaults to [].

  ### Options for `delete`

    * `if_unused` - If set, the server will only delete the exchange
      if it has no queue bindings.
    * `no_wait` - If set, the delete operation is asynchronous.

  """

  use Mix.Task

  @switches [
    connection: :string,
    options: :string
  ]
  @commands ~w|declare create delete|

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
         :ok <- do_command(chan, String.to_atom(command), name, opts) do
      Mix.shell().info("Success.")
    else
      amqp_base_error ->
        Mix.raise("Cannot execute command on target. Error:\n" <> inspect(amqp_base_error))
    end
  end

  @doc false
  def run(_),
    do:
      Mix.raise(
        "Usage: mix rambla.rabbit.exchange (" <> Enum.join(@commands, "|") <> ") name [opts]"
      )

  @spec do_command(
          chan :: AMQP.Channel.t(),
          command :: atom(),
          name :: binary(),
          opts :: keyword()
        ) :: {:ok, binary()} | {:error, any()}
  defp do_command(chan, :create, name, opts),
    do: do_command(chan, :declare, name, opts)

  defp do_command(chan, :declare, name, opts) do
    {type, opts} = Keyword.pop(opts, :type, :direct)
    AMQP.Exchange.declare(chan, name, type, opts)
  end

  defp do_command(chan, :delete, name, opts) do
    {_type, opts} = Keyword.pop(opts, :type, :direct)
    AMQP.Exchange.delete(chan, name, opts)
  end
end
