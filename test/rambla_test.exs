defmodule Test.Rambla do
  # use ExUnit.Case, async: true
  use ExUnit.Case, async: false
  doctest Rambla

  import Mox

  setup :set_mox_global
  setup :verify_on_exit!

  setup_all do
    # v1.0
    modern_amqp =
      start_supervised!(
        {Rambla.Handlers.Amqp, [connection_options: [exchange: "amq.direct"], count: 3]}
      )

    modern_redis =
      start_supervised!({Rambla.Handlers.Redis, [count: 3]})

    modern_httpc =
      start_supervised!({Rambla.Handlers.Httpc, [count: 2]})

    modern_smtp =
      start_supervised!({Rambla.Handlers.Smtp, [count: 2]})

    modern_s3 =
      start_supervised!({Rambla.Handlers.S3, [count: 2]})

    modern_mock =
      start_supervised!({Rambla.Handlers.Mock, [count: 2]})

    modern_stub =
      start_supervised!({Rambla.Handlers.Stub, [count: 2]})

    # v0.0

    opts = [
      {:amqp,
       [
         options: [size: 5, max_overflow: 300],
         type: :local,
         params: Application.fetch_env!(:rambla, :pools)[:amqp]
       ]},
      {{Rambla.Amqp, :other},
       [
         options: [size: 5, max_overflow: 100],
         type: :local,
         params: Application.fetch_env!(:rambla, :pools)[:amqp]
       ]},
      {Rambla.Redis, params: Application.fetch_env!(:rambla, :pools)[:redis]},
      {Rambla.Http, params: Application.fetch_env!(:rambla, :pools)[:http]},
      {Rambla.Foo, [options: [], type: :local, params: [bar: :baz]]},
      {Rambla.Process, params: [callback: self()]}
    ]

    Application.ensure_all_started(:amqp)
    Application.ensure_all_started(:phoenix_pubsub)
    Application.ensure_all_started(:envio)

    pools =
      [
        [pool: {:ok, _}, synch: {:ok, _}],
        [pool: {:ok, _}, synch: {:ok, _}],
        [pool: {:ok, _}, synch: {:ok, _}],
        [pool: {:ok, _}, synch: {:ok, _}],
        [pool: {:ok, _}, synch: {:ok, _}],
        [pool: {:ok, _}, synch: {:ok, _}]
      ] = Rambla.ConnectionPool.start_pools(opts, %{Rambla.Foo => Rambla.Process})

    Application.ensure_all_started(:telemetria)

    %{
      pools: pools,
      modern_amqp: modern_amqp,
      modern_redis: modern_redis,
      modern_httpc: modern_httpc,
      modern_smtp: modern_smtp,
      modern_s3: modern_s3,
      modern_mock: modern_mock,
      modern_stub: modern_stub
    }
  end

  test "pools are ok", %{pools: pools} do
    assert Enum.flat_map(pools, fn p -> p |> Keyword.values() |> Enum.map(&elem(&1, 1)) end) ==
             Enum.map(Rambla.pools(), &elem(&1, 1))
  end

  test "modern works with rabbit" do
    Rambla.Handlers.Amqp.publish(:chan_1, %{message: %{foo: 42}, exchange: "rambla-exchange-1"})

    {:ok, conn} = AMQP.Application.get_connection(:local_conn)
    {:ok, chan} = AMQP.Channel.open(conn)
    {result, tag} = amqp_wait(chan, "rambla-queue-1", "{\"foo\":42}")

    assert result
    assert :ok = AMQP.Basic.ack(chan, tag)
    assert {:empty, _} = AMQP.Basic.get(chan, "rambla-queue-1")
    AMQP.Channel.close(chan)
  end

  test "modern works with rabbit: bulk update" do
    Rambla.Handlers.Amqp.publish(:chan_1, [
      %{
        message: %{bar: 42},
        exchange: "rambla-exchange-4"
      },
      %{
        message: %{baz: 42},
        exchange: "rambla-exchange-4"
      }
    ])

    {:ok, conn} = AMQP.Application.get_connection(:local_conn)
    {:ok, chan} = AMQP.Channel.open(conn)

    [{result1, tag1}, {result2, tag2}] = [
      amqp_wait(chan, "rambla-queue-4", "{\"bar\":42}"),
      amqp_wait(chan, "rambla-queue-4", "{\"baz\":42}")
    ]

    assert result1 and result2
    assert [:ok, :ok] = Enum.map([tag1, tag2], &AMQP.Basic.ack(chan, &1))
    assert {:empty, _} = AMQP.Basic.get(chan, "rambla-queue-4")
    AMQP.Channel.close(chan)
  end

  test "works with rabbit" do
    Rambla.ConnectionPool.publish(Rambla.Amqp, %{foo: 42}, %{
      queue: "rambla-queue-1",
      exchange: "rambla-exchange-1"
    })

    %Rambla.Connection{conn: %{conn: %AMQP.Connection{} = conn}} =
      Rambla.ConnectionPool.conn(Rambla.Amqp)

    {:ok, chan} = AMQP.Channel.open(conn)
    {result, tag} = amqp_wait(chan, "rambla-queue-1", "{\"foo\":42}")

    assert result
    assert :ok = AMQP.Basic.ack(chan, tag)
    assert {:empty, _} = AMQP.Basic.get(chan, "rambla-queue-1")
    AMQP.Channel.close(chan)
  end

  test "works with rabbit (synch)" do
    %Rambla.Connection{conn: %{conn: %AMQP.Connection{} = conn}} =
      Rambla.ConnectionPool.conn(Rambla.Amqp)

    92..110
    |> Enum.map(fn i ->
      Task.async(fn ->
        Rambla.publish_synch(:amqp, %{synch: i}, %{
          queue: "rambla-queue-2",
          exchange: "rambla-exchange-2"
        })
      end)
    end)
    |> Task.await_many()

    {:ok, chan} = AMQP.Channel.open(conn)
    {result, tag} = amqp_wait(chan, "rambla-queue-2", "{\"synch\":110}")

    assert result
    assert :ok = AMQP.Basic.ack(chan, tag)

    Enum.reduce_while(92..110, :non_empty, fn _, :non_empty ->
      case AMQP.Basic.get(chan, "rambla-queue-2") do
        {:empty, _} = exhausted -> {:halt, exhausted}
        _ -> {:cont, :non_empty}
      end
    end)

    assert {:empty, _} = AMQP.Basic.get(chan, "rambla-queue-2")
    AMQP.Channel.close(chan)
  end

  test "accepts keywords as opts" do
    Rambla.publish(Rambla.Amqp, %{foo: 42}, %{
      queue: "rambla-queue-3",
      exchange: "rambla-exchange-3"
    })

    %Rambla.Connection{conn: %{conn: %AMQP.Connection{} = conn}} =
      Rambla.ConnectionPool.conn(Rambla.Amqp)

    {:ok, chan} = AMQP.Channel.open(conn)
    {result, tag} = amqp_wait(chan, "rambla-queue-3", "{\"foo\":42}")

    assert result
    assert :ok = AMQP.Basic.ack(chan, tag)
    assert {:empty, _} = AMQP.Basic.get(chan, "rambla-queue-3")
    AMQP.Channel.close(chan)
  end

  test "works with rabbit: bulk update" do
    Rambla.ConnectionPool.publish(Rambla.Amqp, [%{bar: 42}, %{baz: 42}], %{
      queue: "rambla-queue-4",
      exchange: "rambla-exchange-4"
    })

    %Rambla.Connection{conn: %{conn: %AMQP.Connection{} = conn}} =
      Rambla.ConnectionPool.conn(Rambla.Amqp)

    {:ok, chan} = AMQP.Channel.open(conn)

    [{result1, tag1}, {result2, tag2}] = [
      amqp_wait(chan, "rambla-queue-4", "{\"bar\":42}"),
      amqp_wait(chan, "rambla-queue-4", "{\"baz\":42}")
    ]

    assert result1 and result2
    assert [:ok, :ok] = Enum.map([tag1, tag2], &AMQP.Basic.ack(chan, &1))
    assert {:empty, _} = AMQP.Basic.get(chan, "rambla-queue-4")
    AMQP.Channel.close(chan)
  end

  test "works with different rabbits" do
    Rambla.ConnectionPool.publish(Rambla.Amqp, [%{bar: 42}, %{baz: 42}], %{
      queue: "rambla-queue-5",
      exchange: "rambla-exchange-5"
    })

    Rambla.ConnectionPool.publish({Rambla.Amqp, :other}, %{baqq: 42}, %{
      exchange: "rambla-exchange-5"
    })

    %Rambla.Connection{conn: %{conn: %AMQP.Connection{} = conn}} =
      Rambla.ConnectionPool.conn(Rambla.Amqp)

    {:ok, chan} = AMQP.Channel.open(conn)

    [{result1, tag1}, {result2, tag2}, {result3, tag3}] = [
      amqp_wait(chan, "rambla-queue-5", "{\"bar\":42}"),
      amqp_wait(chan, "rambla-queue-5", "{\"baz\":42}"),
      amqp_wait(chan, "rambla-queue-5", "{\"baqq\":42}")
    ]

    assert result1 and result2 and result3
    assert [:ok, :ok, :ok] = Enum.map([tag1, tag2, tag3], &AMQP.Basic.ack(chan, &1))
    assert {:empty, _} = AMQP.Basic.get(chan, "rambla-queue-5")
    AMQP.Channel.close(chan)
  end

  test "works with redis (hacky low-level)" do
    Rambla.ConnectionPool.publish(Rambla.Redis, %{foo: 42})

    %Rambla.Connection{conn: %Rambla.Connection.Config{conn: pid}} =
      Rambla.ConnectionPool.conn(Rambla.Redis)

    assert {:ok, "42"} = Redix.command(pid, ["GET", "foo"])
    assert {:ok, 1} = Redix.command(pid, ["DEL", "foo"])
    assert {:ok, nil} == Redix.command(pid, ["GET", "foo"])
  end

  test "works with redis" do
    Rambla.publish(Rambla.Redis, %{foo: 42})

    raw_response =
      Rambla.raw(Rambla.Redis, fn pid ->
        r1 = Redix.command(pid, ["GET", "foo"])
        r2 = Redix.command(pid, ["DEL", "foo"])
        r3 = Redix.command(pid, ["GET", "foo"])
        {r1, r2, r3}
      end)

    assert raw_response == {:ok, {{:ok, "42"}, {:ok, 1}, {:ok, nil}}}
  end

  test "works with process" do
    Rambla.ConnectionPool.publish(Rambla.Process, %{__action__: self(), foo: 42})

    assert_receive %{message: %{foo: 42}, payload: %{}}
  end

  test "works with mocks" do
    Rambla.ConnectionPool.publish(Rambla.Foo, %{__action__: self(), foo: 42})
    assert_receive %{message: %{foo: 42}, payload: %{bar: :baz}}
  end

  test "modern works with httpc" do
    Rambla.Handlers.Httpc.publish(:chan_1, %{foo: 42}, self())
    assert_receive {:transition, :success, _, _}, 3_000

    Rambla.Handlers.Httpc.publish(:chan_2, %{foo: 42}, self())
    assert_receive {:transition, :failure, _, _}, 3_000

    Rambla.Handlers.Httpc.publish(
      :chan_1,
      %{message: %{foo: 42}, uri_merge: "/status/500"},
      self()
    )

    assert_receive {:transition, :failure, _, _}, 3_000
  end

  @tag :skip
  test "modern works with smtp" do
    Rambla.Handlers.Smtp.publish(
      :chan_3,
      %{message: "Hi, John!\nComo estas?", to: "am@ambment.cat", retries: 1},
      self()
    )

    assert_receive {:transition, :success, _, _}, 5_000
  end

  test "modern works with s3" do
    expect(Rambla.Mocks.ExAws, :request, fn operation, %{} = _params ->
      assert %ExAws.Operation.S3{} = operation
      assert operation.http_method == :put
      assert operation.bucket == "test-bucket"
      assert operation.path == "some/path"

      {:ok, %{body: "file contents"}}
    end)

    Rambla.Handlers.S3.publish(:chan_1, %{message: "file contents"}, self())
    assert_receive {:transition, :success, _, _}, 1_000
  end

  test "modern use generic mocks" do
    expect(Rambla.Mocks.Generic, :on_publish, fn name, message, opts ->
      assert name == :chan_0
      assert message == "file contents"
      assert map_size(opts) == 0

      {:ok, %{body: "file contents"}}
    end)

    Rambla.publish(:chan_0, %{message: "file contents"}, self())
    assert_receive {:transition, :success, _, _}, 1_000
  end

  test "modern use generic stubs" do
    Rambla.publish(:chan_stub, %{message: "file contents"}, self())
    assert_receive {:transition, :success, _, _}, 1_000
  end

  defp amqp_wait(chan, queue, expected, times \\ 10)
  defp amqp_wait(_chan, _queue, _expected, times) when times <= 0, do: {false, :timeout}

  defp amqp_wait(chan, queue, expected, times) do
    case AMQP.Basic.get(chan, queue) do
      {:ok, ^expected, %{delivery_tag: tag}} -> {true, tag}
      {:ok, _not_expected, %{delivery_tag: _tag}} -> amqp_wait(chan, queue, expected, times)
      {:empty, _} -> Process.sleep(100) && amqp_wait(chan, queue, expected, times - 1)
      other -> {false, other}
    end
  end
end
