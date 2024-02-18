mocks = Application.compile_env(:rambla, :mocks)

if Keyword.keyword?(mocks) and Keyword.get(mocks, :s3) do
  Mox.defmock(Rambla.Mocks.ExAws, for: ExAws.Behaviour)
end
