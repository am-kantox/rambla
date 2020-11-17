defmodule RamblaTest do
  use ExUnit.Case, async: true
  doctest Rambla

  setup_all do
    opts = [
      {Rambla.Amqp,
       [
         options: [size: 5, max_overflow: 300],
         type: :local,
         params: Application.fetch_env!(:rambla, :amqp)
       ]},
      {Rambla.Redis, params: Application.fetch_env!(:rambla, :pools)[:redis]},
      {Rambla.Http, params: Application.fetch_env!(:rambla, :pools)[:http]}
    ]

    Application.ensure_all_started(:amqp)
    Application.ensure_all_started(:phoenix_pubsub)
    Application.ensure_all_started(:envio)

    [
      [pool: {:ok, _}, synch: {:ok, _}],
      [pool: {:ok, _}, synch: {:ok, _}],
      [pool: {:ok, _}, synch: {:ok, _}]
    ] = Rambla.ConnectionPool.start_pools(opts)

    Application.ensure_all_started(:telemetria)

    :ok
  end

  test "works with rabbit" do
    Rambla.ConnectionPool.publish(Rambla.Amqp, %{foo: 42}, %{
      queue: "rambla-queue-1",
      exchange: "rambla-exchange-1"
    })

    %Rambla.Connection{conn: %{chan: %AMQP.Channel{} = chan}} =
      Rambla.ConnectionPool.conn(Rambla.Amqp)

    {result, tag} = amqp_wait(chan, "rambla-queue-1", "{\"foo\":42}")

    assert result
    assert :ok = AMQP.Basic.ack(chan, tag)
    assert {:empty, _} = AMQP.Basic.get(chan, "rambla-queue-1")
  end

  test "works with rabbit (synch)" do
    Rambla.ConnectionPool.publish_synch(Rambla.Amqp, %{synch: 94}, %{
      queue: "rambla-queue-2",
      exchange: "rambla-exchange-2"
    })

    %Rambla.Connection{conn: %{chan: %AMQP.Channel{} = chan}} =
      Rambla.ConnectionPool.conn(Rambla.Amqp)

    {result, tag} = amqp_wait(chan, "rambla-queue-2", "{\"synch\":94}")

    assert result
    assert :ok = AMQP.Basic.ack(chan, tag)
    assert {:empty, _} = AMQP.Basic.get(chan, "rambla-queue-2")
  end

  test "accepts keywords as opts" do
    Rambla.publish(Rambla.Amqp, %{foo: 42}, %{
      queue: "rambla-queue-3",
      exchange: "rambla-exchange-3"
    })

    %Rambla.Connection{conn: %{chan: %AMQP.Channel{} = chan}} =
      Rambla.ConnectionPool.conn(Rambla.Amqp)

    {result, tag} = amqp_wait(chan, "rambla-queue-3", "{\"foo\":42}")

    assert result
    assert :ok = AMQP.Basic.ack(chan, tag)
    assert {:empty, _} = AMQP.Basic.get(chan, "rambla-queue-3")
  end

  test "works with rabbit: bulk update" do
    Rambla.ConnectionPool.publish(Rambla.Amqp, [%{bar: 42}, %{baz: 42}], %{
      queue: "rambla-queue-4",
      exchange: "rambla-exchange-4"
    })

    %Rambla.Connection{conn: %{chan: %AMQP.Channel{} = chan}} =
      Rambla.ConnectionPool.conn(Rambla.Amqp)

    [{result1, tag1}, {result2, tag2}] = [
      amqp_wait(chan, "rambla-queue-4", "{\"bar\":42}"),
      amqp_wait(chan, "rambla-queue-4", "{\"baz\":42}")
    ]

    assert result1 and result2
    assert [:ok, :ok] = Enum.map([tag1, tag2], &AMQP.Basic.ack(chan, &1))
    assert {:empty, _} = AMQP.Basic.get(chan, "rambla-queue-4")
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

  defp amqp_wait(chan, queue, expected, times \\ 10)
  defp amqp_wait(chan, queue, expected, times) when times <= 0, do: {false, :timeout}

  defp amqp_wait(chan, queue, expected, times) do
    case AMQP.Basic.get(chan, queue) do
      {:ok, ^expected, %{delivery_tag: tag}} -> {true, tag}
      {:empty, _} -> amqp_wait(chan, queue, expected, times - 1)
      other -> {false, other}
    end
  end
end
