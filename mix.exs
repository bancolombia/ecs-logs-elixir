defmodule EcsElixirLogs.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :ecs_logs_elixir,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        credo: :test,
        dialyzer: :test,
        coveralls: :test,
        "coveralls.xml": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.github": :test,
        "coveralls.lcov": :test
      ],
      docs: [
        extras: ["README.md"],
        main: "readme",
        source_ref: "v#{@version}"
      ],
      metrics: false
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README", "LICENSE*"],
      maintainers: ["Jhonatan Hidalgo", "Nicolas Figueroa"],
      licenses: ["Apache 2.0"]
    ]
  end

  defp description() do
    "An Elixir library for generating logs in compliance with the Elastic Common Schema (ECS) standard."
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},
      {:timex, "~> 3.7"},
      {:uuid, "~> 1.1"},
      # Tests and Analysis
      {:mock, "~> 0.3", [only: [:dev, :test]]},
      {:excoveralls, "~> 0.18", [only: [:dev, :test]]},
      # {:git_hooks, "~> 0.8", [only: [:dev, :test], runtime: false]},
      {:credo, "~> 1.7", [only: [:dev, :test], runtime: false]},
      {:dialyxir, "~> 1.4", [only: [:dev, :test], runtime: false]}
    ]
  end
end
