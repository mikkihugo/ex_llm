defmodule ExOrchestrator.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_orchestrator,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.10"},
      {:postgrex, "~> 0.17"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.31", only: :dev}
    ]
  end

  defp description do
    """
    ExOrchestrator - Complete workflow orchestration for Elixir.

    A unified package providing PGMQ-based message queuing, HTDAG goal decomposition,
    workflow execution, and real-time notifications. Converts high-level goals into
    executable task graphs with automatic dependency resolution and parallel execution.
    """
  end

  defp package do
    [
      files: ["lib", "priv", "mix.exs", "README.md"],
      maintainers: ["Singularity"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/singularityai/ex_orchestrator",
        "Docs" => "https://hexdocs.pm/ex_orchestrator"
      }
    ]
  end

  defp docs do
    [
      main: "ExOrchestrator",
      extras: ["README.md"],
      groups_for_modules: [
        "Core": [
          ExOrchestrator,
          ExOrchestrator.WorkflowComposer,
          ExOrchestrator.HTDAG,
          ExOrchestrator.Notifications
        ],
        "Execution": [
          ExOrchestrator.Executor,
          ExOrchestrator.FlowBuilder
        ],
        "Decomposers": [
          ExOrchestrator.HTDAG.ExampleDecomposer
        ],
        "Optimization": [
          ExOrchestrator.HTDAGOptimizer
        ],
        "Internals": [
          ExOrchestrator.Config,
          ExOrchestrator.Repository,
          ExOrchestrator.Schemas
        ]
      ]
    ]
  end
end