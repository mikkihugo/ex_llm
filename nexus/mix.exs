defmodule Nexus.MixProject do
  use Mix.Project

  def project do
    [
      app: :nexus,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Nexus.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # LLM client library (local fork)
      {:ex_llm, path: "../packages/ex_llm"},

      # Workflow orchestration (local fork)
      {:ex_pgflow, path: "../packages/ex_pgflow"},

      # JSON encoding/decoding
      {:jason, "~> 1.4"},

      # PostgreSQL message queue (brought in by ex_pgflow, kept for explicit usage)
      {:pgmq, "~> 0.4.0"},

      # PostgreSQL driver (brought in by ex_pgflow)
      {:postgrex, "~> 0.21"},

      # Ecto database wrapper (brought in by ex_pgflow, needed for OAuth tokens)
      {:ecto_sql, "~> 3.12"},

      # UUID generation (UUIDv7 with timestamp ordering)
      {:uniq, "~> 0.6"}
    ]
  end
end
