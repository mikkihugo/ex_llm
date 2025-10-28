defmodule BroadwayPgflow.MixProject do
  use Mix.Project

  def project do
    [
      app: :broadway_pgflow,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Broadway-compatible producer backed by PGFlow workflows for durability and orchestration.",
      package: package(),
      dialyzer: [plt_add_deps: :transitive]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:broadway, "~> 1.0"},
            {:ex_pgflow, path: "../ex_pgflow"},
      {:ecto_sql, "~> 3.10"}
    ]
  end

  defp package do
    [
      name: "broadway_pgflow",
      files: ~w(lib .formatter.exs mix.exs README.md),
      maintainers: ["Your Name"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/yourorg/broadway_pgflow"}
    ]
  end
end