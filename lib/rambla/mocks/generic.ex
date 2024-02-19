mox = Application.compile_env(:rambla, :mock)

if Keyword.keyword?(mox) do
  Mox.defmock(Rambla.Mocks.Generic, for: Rambla.Handlers.Mock)

  mox
  |> get_in([:channels, Access.all(), Access.elem(1), :options, :mock])
  |> List.flatten()
  |> Enum.reject(&is_nil/1)
  |> Enum.each(&Mox.defmock(&1, for: Rambla.Handlers.Mock))
end
