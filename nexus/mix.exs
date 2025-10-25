defmodule Nexus.MixProject do
  use Mix.Project

  def project do
    [
      app: :nexus,
      version: "0.1.0",
      elixir: "~> 1.18",
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

      # JSON encoding/decoding
      {:jason, "~> 1.4"},

      # PostgreSQL message queue
      {:pgmq, "~> 0.4.0"},

      # PostgreSQL driver (required by pgmq)
      {:postgrex, "~> 0.21"},

      # UUID generation (UUIDv7 with timestamp ordering)
      {:uniq, "~> 0.6"}
    ]
  end
end
