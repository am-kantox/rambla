defmodule Rambla.Mocks.Stub do
  @moduledoc false

  require Logger

  @behaviour Rambla.Handlers.Stub
  def on_publish(name, message, options) do
    Logger.info("[🖇️] STUBBED CALL [#{name}] with " <> inspect(message: message, options: options))
  end
end
