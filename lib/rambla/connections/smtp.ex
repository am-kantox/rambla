defmodule Rambla.Smtp do
  @moduledoc """
  Default connection implementation for 📧 SMTP.

  It expects a message to be a map containing the following fields:
  `:to`, `:subject`, `:body` _and_ the optional `:from` that otherwise would be
  taken from the global settings (`releases.mix`) from `[]:rambla, :pools, Rambla.Smtp]`.

  For instance, this call would send an email to email:am@example.com with the
  respective subject and body.

  ```elixir
  Rambla.publish(
    Rambla.Smtp,
    %{to: "am@example.com", subject: "Hi there", body: "I ❤ SMTP"}
  }
  ```
  """
  @behaviour Rambla.Connection

  @conn_params ~w|relay username password auth ssl tls tls_options hostname retries|a

  @impl Rambla.Connection
  def connect(params) when is_list(params) do
    if is_nil(params[:hostname]),
      do:
        raise(Rambla.Exceptions.Connection,
          value: params,
          expected: "📧 configuration with :host key"
        )

    [defaults, opts] =
      params
      |> Keyword.split(@conn_params)
      |> Tuple.to_list()
      |> Enum.map(&Map.new/1)

    %Rambla.Connection{
      conn: %{conn: params[:hostname], opts: opts, defaults: defaults},
      conn_type: __MODULE__,
      conn_pid: self(),
      conn_params: params,
      errors: []
    }
  end

  @impl Rambla.Connection
  def publish(%{conn: conn, opts: opts, defaults: defaults}, message) when is_binary(message),
    do: publish(%{conn: conn, opts: opts, defaults: defaults}, Jason.decode!(message))

  @impl Rambla.Connection
  def publish(%{conn: _conn, opts: opts, defaults: defaults}, message)
      when is_map(opts) and is_map(message) do
    {to, message} = Map.pop(message, :to)
    {from, message} = Map.pop(message, :from, Map.get(opts, :from, []))
    {subject, message} = Map.pop(message, :subject, Map.pop(opts, :subject, ""))
    {body, _message} = Map.pop(message, :body, Map.pop(opts, :body, ""))

    from_with_name = for {name, email} <- from, do: "#{name} <#{email}>"

    smtp_message =
      ["Subject: ", "From: ", "To: ", "\r\n"]
      |> Enum.zip([subject, hd(from_with_name), to, body])
      |> Enum.map(&(&1 |> Tuple.to_list() |> Enum.join()))
      |> Enum.join("\r\n")

    :gen_smtp_client.send(
      {to, Map.values(from), smtp_message},
      defaults
      |> Map.merge(Map.take(opts, @conn_params))
      |> Map.to_list()
    )
  end
end
