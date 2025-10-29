defmodule Nexus.MixProject do
  use Mix.Project

  def project do
    [
      app: :nexus,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      apps_path: ".",
      apps: [
        :singularity,
        :genesis,
        :central_services,
        :ex_llm
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :runtime_tools, :sasl],
      mod: {Nexus.Application, []},
      applications: [
        :singularity,
        :genesis,
        :central_services,
        :ex_llm
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # HTTP client for OAuth2 and API calls
      {:req, "~> 0.5.0"},

      # JSON encoding/decoding
      {:jason, "~> 1.4"},

      # TOML parsing for Codex config
      {:toml, "~> 0.7"},

      # Mocking library for tests (HTTP and database mocking)
      {:mox, "~> 1.0", only: :test},

      # Code coverage reporting
      {:excoveralls, "~> 0.18", only: :test},

      # ex_pgflow dependencies
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.19.0 and < 2.0.0"},
      {:castore, "~> 1.0"}
    ]
  end
end
