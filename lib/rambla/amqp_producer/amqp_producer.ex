defmodule Rambla.AMQPProducer do
  @moduledoc false

  use GenServer

  alias AMQPHelpers.Reliability.Producer, as: AMQPHelpersProducer

  def start_link(opts \\ []) do
    channel = Keyword.get(opts, :channel)

    GenServer.start_link(__MODULE__, channel, opts)
  end

  @impl true
  def init(channel), do: AMQPHelpersProducer.start_link(channel_name: channel, name: channel)

  # Client API

  @spec get_channel(name :: atom()) :: pid() | nil
  def get_channel(name), do: GenServer.whereis(name)
end
