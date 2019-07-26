defmodule RamblaTest do
  use ExUnit.Case
  doctest Rambla

  test "starts connection pool for rabbit" do
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

    children = Rambla.ConnectionPool.start_pools(opts) |> IO.inspect(label: "Children")
  end
end
