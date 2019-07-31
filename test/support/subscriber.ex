defmodule Rambla.Support.Subscriber do
  use Envio.Subscriber, channels: [{Rambla.ConnectionPool, Rambla.Amqp}]

  def handle_envio(message, state) do
    {:noreply, state} = super(message, state)
    IO.inspect({message, state}, label: "Received")
    {:noreply, state}
  end
end
