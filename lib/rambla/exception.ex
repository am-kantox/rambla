defmodule Rambla.Exception do
  @moduledoc """
  Base type for all the `Rambla` exceptions.
  """

  @typedoc """
  `Rambla` exception contains:

  - `reason` the string describing the error in human-readable form
  - `source` usually the type/action this error is originated from
  - `info` free-style map containig additional information (not displayed by default)
  """
  @type t :: %{
          reason: any(),
          source: atom(),
          cause: Rambla.Exception.t() | nil
        }

  defmacro __using__(_opts \\ []) do
    quote location: :keep do
      @moduledoc false
      defexception [:reason, :source, :info]

      @impl true
      def message(%__MODULE__{reason: reason, source: source}),
        do: "✗ " <> inspect(source) <> ": " <> reason

      @impl true
      def exception(opts) do
        source = Keyword.get(opts, :source, "🤷")
        reason = Keyword.get(opts, :reason, "Unexpected error (blame AM)")
        info = Keyword.get(opts, :info, %{})
        %__MODULE__{reason: reason, source: source, info: info}
      end

      defimpl Inspect do
        def inspect(%type{} = data, opts), do: type.message(data)
      end
    end
  end

  @doc false
  @spec reduce(exs :: [Rambla.Exception.t()]) :: binary()
  def reduce(exs) do
    exs
    |> Enum.reverse()
    |> Enum.map_join("\n", & &1.message)
  end
end

defmodule Rambla.Exceptions.Connection do
  @moduledoc """
  The instance of generic `Rambla.Exception`, to be raised/created
  when some connection issues happen.
  """
  use Rambla.Exception
end

defmodule Rambla.Exceptions.Unknown do
  @moduledoc """
  The instance of generic `Rambla.Exception`, has no specific behaviour.

  This module is introduced to simplify pattern matching / distinguishing between
  different types of exceptions.

  Basically, `Rambla.Exception.Unknown` is raised during compile-time,
  `Rambla.Exception.Connection` is an exception caused by connection issues, etc.
  """
  use Rambla.Exception
end
