import Config

if File.exists?(Path.join("config", "#{Mix.env()}.exs")),
  do: import_config("#{Mix.env()}.exs")
