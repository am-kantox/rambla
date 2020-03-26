defmodule Rambla.MixProject do
  use Mix.Project

  @app :rambla
  @version "0.5.3"
  System.put_env("MIX_LOADED_APP", to_string(@app))

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      package: package(),
      aliases: aliases(),
      deps: deps(),
      description: "Easy publishing to many different targets",
      name: "Rambla",
      xref: [exclude: []],
      docs: docs(),
      dialyzer: [
        plt_file: {:no_warn, ".dialyzer/plts/dialyzer.plt"},
        plt_add_apps: [:amqp, :exredis, :httpc, :inets, :ssl],
        ignore_warnings: ".dialyzer/ignore.exs"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:lager, :logger, :poolboy, :envio, :inets, :ssl],
      mod: {Rambla.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:ci), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      quality: ["format", "credo --strict", "dialyzer"],
      "quality.ci": [
        "format --check-formatted",
        "credo --strict",
        "dialyzer --halt-exit-status"
      ]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.0"},
      {:poolboy, "~> 1.5"},
      {:plug, "~> 1.9"},

      # optional backends
      {:amqp, "~> 1.2", optional: true},
      {:exredis, "~> 0.3", optional: true},
      {:envio, "~> 0.4", optional: true},
      {:gen_smtp, "~> 0.15"},

      # dev, test
      {:credo, "~> 1.0", only: [:dev, :ci], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.6", only: [:dev, :ci], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package() do
    [
      # These are the default files included in the package
      files: ~w(lib .formatter.exs .dialyzer/ignore.exs mix.exs README*),
      maintainers: ["Aleksei Matiushkin"],
      licenses: ["Kantox LTD"],
      links: %{"GitHub" => "https://github.com/am-kantox/#{@app}"}
    ]
  end

  defp docs() do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: "https://github.com/am-kantox/#{@app}",
      canonical: "http://hexdocs.pm/#{@app}",
      logo: "stuff/logo-48x48.png",
      extras: ["README.md"],
      groups_for_modules: [
        Backends: [Rambla.Amqp, Rambla.Http, Rambla.Redis, Rambla.Smtp],
        Expections: [Rambla.Exception]
      ]
    ]
  end
end
