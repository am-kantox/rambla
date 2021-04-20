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

  ---

  List of all possible options might be found in
  [`:httpc.request/4`](http://erlang.org/doc/man/httpc.html#request-4), names are preserved.
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
      conn: %Rambla.Connection.Config{conn: params[:host], opts: opts, defaults: defaults},
      conn_type: __MODULE__,
      conn_pid: self(),
      conn_params: params,
      errors: []
    }
  end

  @impl Rambla.Connection
  def publish(%Rambla.Connection.Config{} = conn, message) when is_binary(message),
    do:
      publish(conn, %{
        method: :get,
        host: "",
        port: "",
        path: message
      })

  @impl Rambla.Connection
  def publish(%Rambla.Connection.Config{} = conn, message) when is_binary(message),
    do: publish(conn, Jason.decode!(message))

  @impl Rambla.Connection
  def publish(%Rambla.Connection.Config{} = conn, message) when is_list(message),
    do: publish(conn, Map.new(message))

  @impl Rambla.Connection
  def publish(%Rambla.Connection.Config{opts: opts, defaults: defaults}, message)
      when is_map(opts) and is_map(message) do
    {method, message} = Map.pop(message, :method, :get)

    {host, message} = Map.pop(message, :host, Map.get(defaults, :host))
    {port, message} = Map.pop(message, :port, Map.get(defaults, :port))
    {headers, message} = Map.pop(message, :headers, Map.get(defaults, :headers, []))

    {path, message} = Map.pop(message, :path, Map.get(opts, :path, Map.get(defaults, :path, "")))
    {http_options, message} = Map.pop(message, :http_options, Map.get(opts, :http_options, []))
    {options, message} = Map.pop(message, :options, Map.get(opts, :options, []))
    {%{} = query, message} = Map.pop(message, :query, Map.get(opts, :query, %{}))
    {body, _message} = Map.pop(message, :body, Map.get(opts, :body, %{}))

    host_port =
      [host, port]
      |> Enum.reject(&(to_string(&1) == ""))
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

    headers = for {k, v} <- headers, do: {to_charlist(k), to_charlist(v)}

    request(method, url, headers, body, http_options, options)
  end

  @typep method :: :head | :get | :put | :post | :trace | :options | :delete | :patch
  @typep url :: binary()
  @typep header :: {binary(), binary()}
  @typep headers :: [header()]
  @typep body :: charlist() | binary()

  @typep option ::
           {:sync, boolean()}
           | {:stream, any()}
           | {:body_format, any()}
           | {:full_result, boolean()}
           | {:headers_as_is, boolean()}
           | {:socket_opts, any()}
           | {:receiver, any()}
           | {:ipv6_host_with_brackets, boolean()}
  @typep options :: [option()]
  @typep http_option ::
           {:timeout, timeout()}
           | {:connect_timeout, timeout()}
           | {:ssl, any()}
           | {:essl, any()}
           | {:autoredirect, boolean()}
           | {:proxy_auth, {charlist(), charlist()}}
           | {:version, charlist()}
           | {:relaxed, boolean()}
  @typep http_options :: [http_option()]

  @typep content_type :: charlist()
  @typep status_line :: {charlist(), integer(), charlist()}

  @spec request(
          method :: method(),
          url :: url(),
          headers :: headers(),
          body :: body(),
          http_options :: http_options(),
          options :: options(),
          content_type :: content_type()
        ) :: {:ok, {status_line(), list()}} | {:error, any()}
  defp request(
         method,
         url,
         headers,
         body \\ "",
         http_options \\ [],
         options \\ [],
         content_type \\ 'application/json'
       )

  Enum.each([:post, :put], fn m ->
    defp request(unquote(m), url, headers, body, http_options, options, content_type) do
      :httpc.request(
        unquote(m),
        {to_charlist(url), headers, content_type, body |> Jason.encode!() |> to_charlist()},
        http_options,
        options
      )
    end
  end)

  Enum.each([:get, :head, :options, :delete], fn m ->
    defp request(unquote(m), url, headers, _body, http_options, options, _content_type),
      do: :httpc.request(unquote(m), {to_charlist(url), headers}, http_options, options)
  end)
end
