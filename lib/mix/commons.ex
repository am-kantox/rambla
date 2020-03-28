defmodule Rambla.Tasks.Utils do
  @moduledoc false
  defmacro __using__(opts \\ []) do
    logger =
      opts
      |> Keyword.get(:logger, [])
      |> Keyword.put_new(:level, :warn)

    quote do
      require Logger

      @switches [
        connection: :string,
        options: :string
      ]

      @aliases for {k, _} <- @switches,
                   do: {k |> to_string |> String.at(0) |> String.to_atom(), k}

      @impl Mix.Task
      @doc false
      def run([command, name | args]) when command in @commands do
        Logger.configure(unquote(logger))
        Process.flag(:trap_exit, true)

        {opts, _} = OptionParser.parse!(args, aliases: @aliases, strict: @switches)

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
               |> String.replace(~r/:(?=\d)/, ": ")
               |> String.replace(~r/:(?=\w)/, ": :"),
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
            "Usage: mix #{Mix.Task.task_name(__MODULE__)} (" <>
              Enum.join(@commands, "|") <> ") name [opts]"
          )
    end
  end
end
