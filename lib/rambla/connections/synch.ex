defmodule Rambla.Synch do
  @moduledoc false
  defmacro __using__(opts \\ []) do
    quote do
      use GenServer

      def start_link(opts \\ []) do
        opts = Keyword.merge(opts, unquote(opts))
        GenServer.start_link(__MODULE__, opts, opts)
      end

      @impl GenServer
      def init(opts), do: {:ok, opts}
    end
  end
end
