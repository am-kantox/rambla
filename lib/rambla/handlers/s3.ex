if :s3 in Rambla.services() do
  defmodule Rambla.Handlers.S3 do
    @moduledoc """
    Default handler for _S3 connections. For this handler to work properly,
      one must configure it with 

    ```elixir
    # config :ex_aws,
    #   access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, {:awscli, "default", 30}, :instance_role],
    #   secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, {:awscli, "default", 30}, :instance_role]

    config :ex_aws, 
      access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
      secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role],
      hackney_opts: [follow_redirect: true, recv_timeout: 30_000],
      region: {:system, "AWS_REGION"},
      json_codec: Jason,
      normalize_path: false,
      retries: [
        max_attempts: 1,
        base_backoff_in_ms: 10,
        max_backoff_in_ms: 10_000
      ]

    config :rambla, :s3,
      connections: [
        bucket_1: [bucket: "test-bucket", path: ""]
      ],
      channels: [
        chan_1: [
          connection: :bucket_1,
          options: [connector: ExAws]
        ]
      ]

    # Then you can access the connection/channel via `Rambla.Handlers.S3` as

    Rambla.Handlers.S3.publish(:chan_1, %{message: "Hi John!", connector: Rambla.Mocks.ExAws})
    ```
    """

    use Rambla.Handler

    @impl Rambla.Handler
    @doc false
    def handle_publish(
          %{message: message} = payload,
          %{connection: %{channel: name}} = state
        ) do
      options = extract_options(payload, state)

      conn = config() |> get_in([:channels, name, :connection])
      bucket = get_in(config(), [:connections, conn, :bucket])
      path = get_in(config(), [:connections, conn, :path]) || ""

      {connector, options} = Map.pop(options, :connector, ExAws)

      do_handle_publish(File.exists?(message), connector, {bucket, path}, message, options)
    end

    def handle_publish(callback, %{connection: %{channel: name}, options: _options})
        when is_function(callback, 1) do
      conn = config() |> get_in([:channels, name, :connection])
      bucket_path = get_in(config(), [:connections, conn])

      callback.(bucket_path)
    end

    def handle_publish(payload, state), do: handle_publish(%{message: payload}, state)

    @impl Rambla.Handler
    @doc false
    def config, do: Application.get_env(:rambla, :s3)

    def do_handle_publish(false, connector, {bucket, path}, contents, opts) do
      {connector, bucket, path, contents, opts}

      bucket
      |> ExAws.S3.put_object(path, contents)
      |> connector.request(opts)
    end

    def do_handle_publish(true, connector, {bucket, path}, file, opts) do
      file
      |> ExAws.S3.Upload.stream_file()
      |> ExAws.S3.upload(bucket, path)
      |> connector.request(opts)
    end
  end
end
