if :smtp in Rambla.services() do
  defmodule Rambla.Handlers.Smtp do
    @moduledoc """
    Default handler for _SMTP_ connections. For this handler to work properly,
      one must configure it with 

    ```elixir
    config :rambla, :smtp,
      connections: [
        gmail: [
          # the smtp relay, e.g. "smtp.gmail.com"
          relay: System.get_env("RAMBLA_SMTP_RELAY", "smtp.gmail.com"),
          # the username of the smtp relay e.g. "me@gmail.com"
          username: System.get_env("RAMBLA_SMTP_USERNAME"),
          # the password of the smtp relay e.g. "mypassword"
          password: System.get_env("RAMBLA_SMTP_PASSWORD"),
          # whether the smtp server needs authentication, valid values are if_available and always,
          #   Defaults to if_available. If your smtp relay requires authentication set it to always
          auth: :always,
          # whether to connect on 465 in ssl mode, Defaults to false
          ssl: true,
          # valid values are always, never, if_available.
          #   Most modern smtp relays use tls, so set this to always, Defaults to if_available
          # tls: :always,
          # used in ssl:connect, More info at http://erlang.org/doc/man/ssl.html ,
          #   Defaults to [{versions , ['tlsv1', 'tlsv1.1', 'tlsv1.2']}],
          #   This is merged with options listed at: https://github.com/gen-smtp/gen_smtp/blob/master/src/smtp_socket.erl#L46 .
          #   Any options not present in this list will be ignored.
          # tls_options: [versions: [:tlsv1, :"tlsv1.1", :"tlsv1.2"]],
          # the hostname to be used by the smtp relay,
          #   Defaults to: smtp_util:guess_FQDN().
          #   The hostname on your computer might not be correct, so set this to a valid value.
          hostname: System.get_env("RAMBLA_SMTP_HOSTNAME", "gmail.com"),
          from: %{"Aleksei Matiushkin" => "matiouchkine@gmail.com"}
        ]
      ],
      channels: [
        chan_3: [connection: :gmail]
      ]

    # Then you can access the connection/channel via `Rambla.Handlers.Smtp` as

    Rambla.Handlers.Smtp.publish(:chan_3, "Hi John!\\nHow are you?")
    ```
    """

    @conn_params ~w|relay username password auth ssl tls tls_options hostname retries|a

    use Rambla.Handler

    @impl Rambla.Handler
    @doc false
    def handle_publish(
          %{message: message} = payload,
          %{connection: %{channel: name}} = state
        ) do
      options = extract_options(payload, state)

      conn = config() |> get_in([:channels, name, :connection])
      params = get_in(config(), [:connections, conn])

      {preferred_format, options} = Map.pop(options, :preferred_format, :binary)
      {generator, _options} = Map.pop(options, :generator, nil)

      message = converter(preferred_format, message)

      message =
        if is_nil(generator) do
          if is_binary(message), do: message, else: inspect(message)
        else
          generator.generate(message)
        end

      do_handle_publish(params, message, options)
    end

    def handle_publish(callback, %{connection: %{channel: name}, options: _options})
        when is_function(callback, 1) do
      conn = config() |> get_in([:channels, name, :connection])
      params = get_in(config(), [:connections, conn])

      callback.(params)
    end

    def handle_publish(payload, state), do: handle_publish(%{message: payload}, state)

    @impl Rambla.Handler
    @doc false
    def config, do: Application.get_env(:rambla, :smtp)

    def do_handle_publish(params, body, opts) when is_map(opts) and is_binary(body) do
      params = Map.new(params)

      result =
        with {:ok, to} <- Map.fetch(opts, :to),
             %{} = from when map_size(from) > 0 <-
               Map.get_lazy(opts, :from, fn -> Map.fetch!(params, :from) end),
             subject <- Map.get(opts, :subject, "") do
          from_with_name = for {name, email} <- from, do: "#{name} <#{email}>"

          smtp_message =
            ["Subject: ", "From: ", "To: ", "\r\n"]
            |> Enum.zip([subject, List.first(from_with_name), to, body])
            |> Enum.map_join("\r\n", &(&1 |> Tuple.to_list() |> Enum.join()))

          :gen_smtp_client.send_blocking(
            {to, Map.values(from), smtp_message},
            params
            |> Map.merge(Map.take(opts, @conn_params))
            |> Map.to_list()
          )
        else
          :error -> {:error, "Insufficient params to send email"}
          {:error, reason} -> {:error, reason}
          reason -> {:error, inspect(reason)}
        end

      with {:error, type, reason} <- result,
           do: {:error, Enum.join([type, ": ", inspect(reason)], ",")}
    end
  end
end
