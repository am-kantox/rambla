defmodule RamblaTest do
  use ExUnit.Case
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

    [ok: _, ok: _, ok: _] = Rambla.ConnectionPool.start_pools(opts)
    {:ok, _pid} = Rambla.Support.Subscriber.start_link()

    :ok
  end

  test "works with rabbit" do
    Rambla.ConnectionPool.publish(Rambla.Amqp, %{foo: 42}, %{
      queue: "rambla-queue",
      exchange: "rambla-exchange"
    })

    %Rambla.Connection{conn: %{chan: %AMQP.Channel{} = chan}} =
      Rambla.ConnectionPool.conn(Rambla.Amqp)

    assert {:ok, "{\"foo\":42}", %{delivery_tag: tag} = _meta} =
             AMQP.Basic.get(chan, "rambla-queue")

    assert :ok = AMQP.Basic.ack(chan, tag)
    assert {:empty, _} = AMQP.Basic.get(chan, "rambla-queue")
  end

  test "works with rabbit: bulk update" do
    Rambla.ConnectionPool.publish(Rambla.Amqp, [%{bar: 42}, %{baz: 42}], %{
      queue: "rambla-queue-2",
      exchange: "rambla-exchange-2"
    })

    %Rambla.Connection{conn: %{chan: %AMQP.Channel{} = chan}} =
      Rambla.ConnectionPool.conn(Rambla.Amqp)

    [r1, r2] = [
      AMQP.Basic.get(chan, "rambla-queue-2"),
      AMQP.Basic.get(chan, "rambla-queue-2")
    ]

    assert {:ok, "{\"bar\":42}", %{delivery_tag: tag1} = _meta} = r1
    assert {:ok, "{\"baz\":42}", %{delivery_tag: tag2} = _meta} = r2

    assert :ok = AMQP.Basic.ack(chan, tag1)
    assert :ok = AMQP.Basic.ack(chan, tag2)
    assert {:empty, _} = AMQP.Basic.get(chan, "rambla-queue-2")
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
end
