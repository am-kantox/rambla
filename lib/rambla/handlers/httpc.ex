if :httpc in Rambla.services() do
  defmodule Rambla.Handlers.Httpc do
    @moduledoc """
    Default handler for _HTTP_ connections. For this handler to work properly,
      one must configure it with 

    ```elixir
    config :rambla, :httpc,
      connections: [
        httpbin: "https://httpbin.org/post",
        remote_conn: [scheme: "https", host: "httpbin.org", query: "post"]
      ],
      channels: [
        chan_1: [connection: :httpbin, options: [headers: [{"accept", "application/json"}]]]
      ]

    # Then you can access the connection/channel via `Rambla.Handlers.Amqp` as

    Rambla.Handlers.Httpc.publish(:chan_1, %{message: %{foo: 42}, serializer: Jason})
    ```

    The `publish/2` function receives options which might be used to amend anything,
      including but not limited to `URI`, which would be updated as shown below

    ```elixir
      uri =
        uri
        |> then(&if(uri_path, do: URI.append_path(&1, uri_path), else: &1))
        |> then(&if(uri_query, do: URI.append_query(&1, uri_query), else: &1))
        |> then(&if(uri_merge, do: URI.merge(&1, uri_merge), else: &1))
    ```
    """

    use Rambla.Handler

    @impl Rambla.Handler
    @doc false
    def handle_publish(%{message: message}, options, %{connection: %{channel: name}}) do
      conn = config() |> get_in([:channels, name, :connection])

      uri =
        case get_in(config(), [:connections, conn]) do
          %URI{} = uri -> uri
          "http" <> _ = url -> URI.new!(url)
          %{} = map -> struct!(URI, map)
          [{key, _} | _] = list when is_atom(key) -> struct!(URI, list)
        end

      {preferred_format, options} = Map.pop(options, :preferred_format, :none)
      {serializer, _options} = Map.pop(options, :serializer, Jason)

      message = converter(preferred_format, message)

      body =
        case serializer.encode(message) do
          {:ok, json} -> json
          {:error, _} -> inspect(message)
        end

      do_handle_publish(uri, body, options)
    end

    def handle_publish(callback, options, %{connection: %{channel: name}, options: _options})
        when is_function(callback, 1) do
      conn = config() |> get_in([:channels, name, :connection])
      uri = struct!(URI, get_in(config(), [:connections, conn]))

      callback.(source: __MODULE__, destination: uri, options: options)
    end

    def handle_publish(payload, options, state),
      do: handle_publish(%{message: payload}, options, state)

    @impl Rambla.Handler
    @doc false
    def config, do: Application.get_env(:rambla, :httpc)

    def do_handle_publish(uri, body, opts) when is_map(opts) and is_binary(body) do
      {uri, opts} = do_patch_uri(uri, opts)
      {method, opts} = Map.pop(opts, :method, :post)
      {headers, opts} = Map.pop(opts, :headers, [])
      {http_options, opts} = Map.pop(opts, :http_options, [])
      {content_type, opts} = Map.pop(opts, :content_type, ~c"application/json")
      {options, _opts} = Map.pop(opts, :options, [])

      headers =
        for {k, v} <- headers, do: {:erlang.binary_to_list(k), :erlang.binary_to_list(v)}

      method
      |> request(to_string(uri), headers, body, http_options, options, content_type)
      |> case do
        {:ok, {{_, ok, _}, _, response}} when ok in 200..299 -> {:ok, response}
        # [AM] REDIRECT {:ok, {{_, ok, _}, _, response}} when ok in 300..399 -> {:ok, response}
        {:ok, {{_, ko, _}, _, response}} when ko in 400..499 -> {:ok, response}
        {:ok, {{_, ko, _}, _, response}} when ko in 500..599 -> {:error, response}
        {:error, reason} -> {:error, reason}
      end
    end

    defp do_patch_uri(uri, opts) do
      {uri_path, opts} = Map.pop(opts, :uri_append_path)
      {uri_query, opts} = Map.pop(opts, :uri_append_query)
      {uri_merge, opts} = Map.pop(opts, :uri_merge)

      uri =
        uri
        |> then(&if(uri_path, do: URI.append_path(&1, uri_path), else: &1))
        |> then(&if(uri_query, do: URI.append_query(&1, uri_query), else: &1))
        |> then(&if(uri_merge, do: URI.merge(&1, uri_merge), else: &1))

      {uri, opts}
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
          ) :: {:ok, {status_line(), list(), list()}} | {:error, any()}
    defp request(
           method,
           url,
           headers,
           body,
           http_options,
           options,
           content_type
         )

    Enum.each([:post, :put], fn m ->
      defp request(unquote(m), url, headers, body, http_options, options, content_type) do
        unquote(m)
        |> :httpc.request(
          {:erlang.binary_to_list(url), headers, content_type,
           body |> Jason.encode!() |> :erlang.binary_to_list()},
          http_options,
          options
        )
      end
    end)

    Enum.each([:get, :head, :options, :delete], fn m ->
      defp request(unquote(m), url, headers, _body, http_options, options, _content_type) do
        unquote(m)
        |> :httpc.request({:erlang.binary_to_list(url), headers}, http_options, options)
      end
    end)
  end
end
