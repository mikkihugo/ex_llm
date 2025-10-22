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

      # Background Job Queue for aggregation, package sync, statistics
      {:oban, "~> 2.18"},

      # Cron-like scheduler for periodic global tasks
      {:quantum, "~> 3.5"}
    ]
  end
end
