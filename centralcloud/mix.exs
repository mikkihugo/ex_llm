defmodule Centralcloud.MixProject do
  use Mix.Project

  def project do
    [
      app: :centralcloud,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Centralcloud.Application, []}
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.10"},
      {:postgrex, "~> 0.17"},
      {:pgvector, "~> 0.2"},
      {:jason, "~> 1.4"},
      {:gnat, "~> 1.8"},
      {:req, "~> 0.5"},

      # Background Job Queue for aggregation, package sync, statistics
      {:oban, "~> 2.18"},

      # Cron-like scheduler for periodic global tasks
      {:quantum, "~> 3.5"},

      # Testing dependencies
      {:mox, "~> 1.0", only: :test},
      {:ex_machina, "~> 2.8", only: :test}
    ]
  end
end
