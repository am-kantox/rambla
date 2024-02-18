s3 = Application.compile_env(:rambla, :s3)

if Keyword.keyword?(s3) do
  connectors =
    s3
    |> get_in([:channels, Access.all(), Access.elem(1), :options, :connector])
    |> List.flatten()
    |> Enum.reject(&(&1 == ExAws))

  Enum.each(connectors, &Mox.defmock(&1, for: ExAws.Behaviour))
end
