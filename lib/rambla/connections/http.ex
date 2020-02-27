defmodule Rambla.Http do
  @moduledoc """
  Default connection implementation for 🕸️ HTTP.

  It expects a message to be a map, containing the following fields:
  `:method`, `:path`, `:query`, `:body` _and_ the optional `:type`
  that otherwise would be inferred from the body type.

  For instance, this call would send a POST request with a JSON specified as body.

  ```elixir
  Rambla.publish(
    Rambla.Http,
    %{method: :post, body: %{message: "I ❤ HTTP"}}
  }
  ```

  If the second argument `message` is `binary()` it’s treated as an URL _and_
  `:get` is implied.
  """
  @behaviour Rambla.Connection

  @conn_params ~w|host port|a

  @impl Rambla.Connection
  def connect(params) when is_list(params) do
    if is_nil(params[:host]),
      do:
        raise(Rambla.Exceptions.Connection,
          value: params,
          expected: "🕸️ configuration with :host key"
        )

    [defaults, opts] =
      params
      |> Keyword.split(@conn_params)
      |> Tuple.to_list()
      |> Enum.map(&Map.new/1)

    %Rambla.Connection{
      conn: %{conn: params[:host], opts: opts, defaults: defaults},
      conn_type: __MODULE__,
      conn_pid: self(),
      conn_params: params,
      errors: []
    }
  end

  @impl Rambla.Connection
  def publish(%{conn: conn, opts: opts, defaults: defaults}, message) when is_binary(message),
    do:
      publish(%{conn: conn, opts: opts, defaults: defaults}, %{
        method: :get,
        host: "",
        port: "",
        path: message
      })

  @impl Rambla.Connection
  def publish(%{conn: _conn, opts: opts, defaults: defaults}, message)
      when is_map(opts) and is_map(message) do
    {method, message} = Map.pop(message, :method, :get)
    {host, message} = Map.pop(message, :host, Map.get(defaults, :host))
    {port, message} = Map.pop(message, :port, Map.get(defaults, :port))
    {headers, message} = Map.pop(message, :headers, Map.get(defaults, :headers, []))
    {path, message} = Map.pop(message, :path, Map.get(opts, :path, ""))
    {%{} = query, message} = Map.pop(message, :query, Map.get(opts, :query, %{}))
    {body, _message} = Map.pop(message, :body, Map.get(opts, :body, %{}))

    host_port =
      [host, port]
      |> Enum.reject(&(&1 == ""))
      |> Enum.join(":")

    path_query =
      [path, Plug.Conn.Query.encode(query)]
      |> Enum.map(&String.trim(&1, "/"))
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("?")

    url =
      [host_port, path_query]
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("/")

    request(method, url, headers, body)
  end

  @spec request(
          method :: :httpc.method(),
          url :: :httpc.url(),
          headers :: :httpc.headers(),
          body :: :httpc.body(),
          content_type :: :httpc.content_type()
        ) :: {:ok, {:httpc.status_line(), list()}} | {:error, any()}
  defp request(method, url, headers, body \\ "", content_type \\ 'application/json')

  Enum.each([:post, :put], fn m ->
    defp request(unquote(m), url, headers, body, content_type),
      do:
        :httpc.request(
          unquote(m),
          {to_charlist(url), headers, :erlang.binary_to_list(Jason.encode!(body)), content_type},
          [],
          []
        )
  end)

  Enum.each([:get, :head, :options, :delete], fn m ->
    defp request(unquote(m), url, headers, _body, _content_type),
      do: :httpc.request(unquote(m), {to_charlist(url), headers}, [], [])
  end)
end
