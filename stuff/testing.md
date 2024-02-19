# Testing Rambla

There are two ways to test `Rambla` in the wild. One might do a granular testing as shown
below with `S3` mock example.

```elixir
expect(Rambla.Mocks.ExAws, :request, fn operation, %{} = _params ->
  assert %ExAws.Operation.S3{} = operation
  assert operation.http_method == :put
  assert operation.bucket == "test-bucket"
  assert operation.path == "some/path"

  {:ok, %{body: "file contents"}}
end)

Rambla.Handlers.S3.publish(:chan_1, %{message: "file contents"}, self())
assert_receive {:transition, :success, _, _}, 1_000
```

Another options would be to use `Rambla.Handlers.Mock` with a custom mock.

```elixir
expect(Rambla.Mocks.Generic, :on_publish, fn name, message, %{} = _opts ->
  assert name == :chan_0
  assert message == "file contents"

  {:ok, %{body: "file contents"}}
end)

Rambla.publish(:chan_0, %{message: "file contents"}, self())
assert_receive {:transition, :success, _, _}, 1_000
```
