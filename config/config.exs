import Config

level =
  case Mix.env() do
    :test -> :warning
    :finitomata -> :debug
    :ci -> :debug
    :prod -> :warning
    :dev -> :info
  end

config :telemetria, :backend, :logger

config :logger, level: level
config :logger, :default_handler, level: level
config :logger, :default_formatter, colors: [info: :magenta]
config :logger, compile_time_purge_matching: [[level_lower_than: level]]

if File.exists?(Path.join("config", "#{Mix.env()}.exs")),
  do: import_config("#{Mix.env()}.exs")
