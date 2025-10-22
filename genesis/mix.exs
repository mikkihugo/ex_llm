defmodule Genesis.MixProject do
  use Mix.Project

  def project do
    [
      app: :genesis,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Genesis.Application, []},
      included_applications: [:quantum]
    ]
  end

  defp deps do
    [
      # Core dependencies
      {:ecto_sql, "~> 3.10"},
      {:postgrex, "~> 0.17"},
      {:jason, "~> 1.4"},

      # Messaging (gnat is the Elixir NATS client)
      {:gnat, "~> 1.7"},

      # Scheduling & Background Jobs
      {:oban, "~> 2.18"},
      {:quantum, "~> 3.5"},

      # Development & Testing
      {:mix_test_watch, "~> 1.2", only: :dev},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false}
    ]
  end
end
