defmodule ExPgflow.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_pgflow,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      description: description(),
      source_url: "https://github.com/your-org/ex_pgflow",
      homepage_url: "https://github.com/your-org/ex_pgflow",
      dialyzer: [
        plt_add_apps: [:mix, :ex_unit],
        plt_local_path: "priv/plts"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:oban, "~> 2.17"},
      {:ecto_sql, "~> 3.10"},
      {:ex_doc, "~> 0.31", only: :dev},
      {:credo, "~> 1.7", only: [:dev, :test]},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mix_test_watch, "~> 1.1", only: :dev}
    ]
  end

  defp description do
    """
    Pure Elixir workflow orchestration engine.

    Like pgflow but 100x faster (<1ms vs 10-100ms polling), pure Elixir,
    and with built-in Oban integration for distributed execution.
    """
  end

  defp package do
    [
      files: ~w(lib priv mix.exs README.md LICENSE.md CHANGELOG.md),
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/your-org/ex_pgflow",
        "Compared to pgflow" => "https://github.com/pgflow-dev/pgflow"
      }
    ]
  end

  defp docs do
    [
      extras: [
        "README.md",
        "ARCHITECTURE.md",
        "GETTING_STARTED.md"
      ],
      main: "readme",
      source_ref: "main",
      formatters: ["html"]
    ]
  end
end
