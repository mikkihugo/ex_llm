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

      # HTTP client for OAuth2 and API calls
      {:req, "~> 0.5.0"},

      # JSON encoding/decoding
      {:jason, "~> 1.4"},
      
      # TOML parsing for Codex config
      {:toml, "~> 0.7"},

      # PostgreSQL message queue (brought in by ex_pgflow, kept for explicit usage)
      {:pgmq, "~> 0.4.0"},

      # PostgreSQL driver (brought in by ex_pgflow)
      {:postgrex, "~> 0.21"},

      # Ecto database wrapper (brought in by ex_pgflow, needed for OAuth tokens)
      {:ecto_sql, "~> 3.12"},

      # UUID generation (UUIDv7 with timestamp ordering)
      {:uniq, "~> 0.6"},

      # Mocking library for tests (HTTP and database mocking)
      {:mox, "~> 1.0", only: :test},

      # Code coverage reporting
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end
end
