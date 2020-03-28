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

  @commands ~w|declare create delete|

  use Mix.Task
  use Rambla.Tasks.Utils

  @spec do_command(
          chan :: AMQP.Channel.t(),
          command :: atom(),
          name :: binary(),
          opts :: keyword()
        ) :: :ok | {:error, any()}
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
