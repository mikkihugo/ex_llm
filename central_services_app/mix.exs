defmodule CentralServices.MixProject do
  use Mix.Project

  def project do
    [
      app: :central_services,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {CentralServices.Application, []}
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.10"},
      {:postgrex, "~> 0.17"},
      {:pgvector, "~> 0.2"},
      {:jason, "~> 1.4"},
      {:async_nats, "~> 0.33"}
    ]
  end
end
