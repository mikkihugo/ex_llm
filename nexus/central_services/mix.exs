defmodule CentralServices.MixProject do
  use Mix.Project

  def project do
    [
      app: :central_services,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools, :sasl]
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.10"},
      {:postgrex, "~> 0.17"},
      {:pgvector, "~> 0.2"},
      {:jason, "~> 1.4"},
      {:req, "~> 0.5"},

      # Background Job Queue for aggregation, package sync, statistics
      {:oban, "~> 2.18"},
      # Workflow orchestration via quantum_flow macros
      # NOTE: override: true is necessary due to conflicting env specifications in dependencies
      {:quantum_flow, path: "../../packages/ex_quantum_flow", override: true},
      {:pgmq, "~> 0.4"},
      
      # Data Processing Pipeline for ML training
      {:broadway, "~> 1.0"},

      # ML and Data Science dependencies (optional - only load if needed)
      {:axon, "~> 0.6", optional: true},                    # Deep Learning framework
      {:nx, "~> 0.6", optional: true},                      # Numerical computing (required by Axon)
      {:exla, "~> 0.10", optional: true, app: false, compile: false},                    # GPU acceleration (optional)
      {:yaml_elixir, "~> 2.9", optional: true},             # YAML parsing for static models
      {:yamerl, "~> 0.10", optional: true},                 # Alternative YAML parser
      {:timex, "~> 3.7", optional: true},                   # Time utilities for training data
      {:statistics, "~> 0.6", optional: true},              # Statistical functions for ML
      {:decimal, "~> 2.1", optional: true},                 # High precision decimal arithmetic

      # Testing dependencies
      {:mox, "~> 1.0", only: :test},
      {:ex_machina, "~> 2.8", only: :test},
      
      # Rust NIF Engines (optional, only used if present)
      {:rustler, "~> 0.37", optional: true},
      # architecture_engine removed - uses pure Elixir detectors via NATS delegation to Singularity
      {:code_quality_engine, path: "../../packages/code_quality_engine", runtime: false, app: false, compile: false, optional: true},
      # Embedding calls Singularity via NATS (pure Elixir NxService)
      {:parser_engine, path: "../../packages/parser_engine", runtime: false, app: false, compile: false, optional: true},
      {:prompt_engine, path: "../../packages/prompt_engine", runtime: false, app: false, compile: false, optional: true},
      {:linting_engine, path: "../../packages/linting_engine", runtime: false, app: false, compile: false, optional: true}
    ]
  end
end
