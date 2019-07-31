defmodule RamblaTest do
  use ExUnit.Case
  doctest Rambla

  setup_all do
    opts = [
      {Rambla.Amqp,
       [
         options: [size: 5, max_overflow: 300],
         type: :local,
         params: [
           host: "localhost",
           password: "guest",
           port: 5672,
           username: "guest",
           virtual_host: "/",
           x_message_ttl: "4000"
         ]
       ]},
      {Rambla.Redis,
       [
         params: [
           host: "127.0.0.1",
           port: 6379,
           password: "",
           db: 0,
           reconnect: 1_000,
           max_queue: :infinity
         ]
       ]}
    ]

    [ok: _, ok: _] = Rambla.ConnectionPool.start_pools(opts)

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

  test "works with redis" do
    Rambla.ConnectionPool.publish(Rambla.Redis, %{foo: 42})

    %Rambla.Connection{conn: %{pid: pid}} = Rambla.ConnectionPool.conn(Rambla.Redis)

    assert "42" = Exredis.Api.get(pid, "foo")
    assert 1 = Exredis.Api.del(pid, "foo")
    assert :undefined == Exredis.Api.get(pid, "foo")
  end
end
