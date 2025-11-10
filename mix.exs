defmodule SingularityLLM.MixProject do
  use Mix.Project

  def project do
    [
      app: :singularity_llm,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Elixir LLM service library for Singularity",
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.4"},
      {:jason, "~> 1.4"},
      {:nimble_options, "~> 1.1"},
      {:instructor, "~> 0.1"},
      {:cachex, "~> 4.0"},
      {:telemetry, "~> 1.2"}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/Singularity-ng/singularity-llm"}
    ]
  end
end
