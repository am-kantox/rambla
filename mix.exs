defmodule Rambla.MixProject do
  use Mix.Project

  @app :rambla
  @version "0.16.2"

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: compilers(Mix.env()),
      start_permanent: Mix.env() == :prod,
      package: package(),
      aliases: aliases(),
      deps: deps(),
      description: description(),
      name: "Rambla",
      xref: [exclude: []],
      docs: docs(),
      dialyzer: [
        plt_file: {:no_warn, ".dialyzer/plts/dialyzer.plt"},
        plt_add_deps: :transitive,
        plt_add_apps: [:amqp, :redix, :inets, :ssl, :mix],
        list_unused_filters: true,
        ignore_warnings: ".dialyzer/ignore.exs"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :poolboy, :inets, :ssl],
      mod: {Rambla.Application, []}
    ]
  end

  defp description do
    """
    Easy publishing to many different targets.

    Supported back-ends:

    - Rabbit [Amqp](https://hexdocs.pm/amqp/)
    - Redis [Redix](https://hexdocs.pm/redix)
    - Http [:httpc](http://erlang.org/doc/man/httpc.html)
    - Smtp [:gen_smtp](https://hexdocs.pm/gen_smtp)
    - Slack [Envío](https://hexdocs.pm/envio)
    """
  end

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
      {:boundary, "~> 0.6"},
      {:jason, "~> 1.0"},
      {:tarearbol, "~> 1.6"},
      {:plug, "~> 1.9"},
      {:poolboy, "~> 1.5"},
      {:ranch, "~> 1.7 or ~> 2.0"},

      # optional backends
      {:amqp, "~> 1.2 or ~> 2.0 or ~> 3.0", optional: true},
      {:redix, "~> 1.0", optional: true},
      {:gen_smtp, "~> 0.4 or ~> 1.0", optional: true},
      {:telemetria, "~> 0.4", optional: true},

      # dev, test
      {:credo, "~> 1.0", only: [:dev, :ci], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :ci], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package() do
    [
      # These are the default files included in the package
      files: ~w|lib .formatter.exs .dialyzer/ignore.exs mix.exs README* LICENSE|,
      maintainers: ["Aleksei Matiushkin"],
      licenses: ["Kantox LTD"],
      links: %{"GitHub" => "https://github.com/am-kantox/#{@app}"}
    ]
  end

  defp docs() do
    [
      main: "getting-started",
      source_ref: "v#{@version}",
      source_url: "https://github.com/am-kantox/#{@app}",
      canonical: "http://hexdocs.pm/#{@app}",
      logo: "stuff/logo-48x48.png",
      extras: ["README.md", "stuff/getting-started.md"],
      groups_for_modules: [
        Backends: [Rambla.Amqp, Rambla.Http, Rambla.Redis, Rambla.Smtp],
        Expections: [Rambla.Exception]
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:ci), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp compilers(:test), do: [:telemetria | Mix.compilers()]
  defp compilers(_), do: Mix.compilers()
end
