defmodule Singularity.MixProject do
  use Mix.Project

  @app :singularity

  def project do
    [
      app: @app,
      version: project_version(),
      elixir: ">= 1.20.0-dev",
      elixirc_paths: elixirc_paths(Mix.env()),
      erlc_paths: erlc_paths(Mix.env()),
      erlc_include_path: erlc_include_path(Mix.env()),
      compilers: [:gleam | Mix.compilers()],
      start_permanent: Mix.env() == :prod,
      prune_code_paths: false,
      aliases: aliases(),
      deps: deps(),
      releases: releases(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.html": :test,
        "coveralls.json": :test,
        "coveralls.post": :test,
        test: :test,
        "test.ci": :test,
        quality: :dev
      ],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        flags: [:error_handling, :race_conditions, :underspecs]
      ]
    ]
  end

  def application do
    [
      mod: {Singularity.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp project_version do
    "../VERSION"
    |> Path.expand(__DIR__)
    |> File.read!()
    |> String.trim()
  end

  defp erlc_paths(env) do
    build_path = Path.join(["build", Atom.to_string(env), "erlang", Atom.to_string(@app)])

    [
      Path.join(build_path, "_gleam_artefacts"),
      Path.join(build_path, "build"),
      "gleam/build/dev/erlang"
    ]
  end

  defp erlc_include_path(env) do
    Path.join(["build", Atom.to_string(env), "erlang", Atom.to_string(@app), "include"])
  end

  defp deps do
    [
      # Web & HTTP
      {:bandit, "~> 1.5"},
      {:plug, "~> 1.15"},
      {:finch, "~> 0.17"},
      {:req, "~> 0.5"},

      # Database
      {:ecto, "~> 3.11"},
      {:ecto_sql, "~> 3.11"},
      {:postgrex, ">= 0.0.0"},
      # Vector embeddings for pattern mining
      {:pgvector, "~> 0.2"},

      # ML/AI - Local embeddings with GPU acceleration
      {:bumblebee, "~> 0.5.3"},
      {:nx, "~> 0.7.1"},
      {:exla, "~> 0.7.1"},  # XLA compiler for GPU (CUDA/ROCm)

      # Data & Serialization
      {:jason, "~> 1.4"},
      {:nimble_options, "~> 1.1"},

      # Distributed Systems
      {:libcluster, "~> 3.3"},
      {:delta_crdt, "~> 0.6"},
      # Event bus for coordinators
      {:phoenix_pubsub, "~> 2.1"},

      # Monitoring & Telemetry
      {:telemetry, "~> 1.2"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.1"},

      # SAFe Coordination
      # Job scheduler for PI Planning, System Demos
      {:quantum, "~> 3.5"},

      # MoonShine-style Rule Engine
      # Fast caching for rule results
      {:cachex, "~> 3.6"},
      # Resource pooling for LLM APIs
      {:nimble_pool, "~> 1.0"},

      # MCP (Model Context Protocol)
      {:hermes_mcp, "~> 0.14.1"},

      # Event Processing
      # Data pipelines
      {:broadway, "~> 1.0"},
      # Producer-consumer
      {:gen_stage, "~> 1.2"},
      # Parallel processing
      {:flow, "~> 1.2"},

      # Gleam Integration
      {:gleam_stdlib, "~> 0.65", app: false, manager: :rebar3, override: true},
      {:gleeunit, "~> 1.0", app: false, manager: :rebar3, only: [:dev, :test]},

      # Development & Testing
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      # Test factories
      {:ex_machina, "~> 2.7", only: :test},
      # Mocks
      {:mox, "~> 1.1", only: :test}
    ]
  end

  defp releases do
    [
      singularity: [
        include_executables_for: [:unix],
        applications: [runtime_tools: :permanent],
        steps: [:assemble, :tar]
      ]
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "gleam.deps.get"],
      test: ["test"],
      "test.ci": ["test --color --cover"],
      coverage: ["coveralls.html"],
      quality: [
        "format",
        "credo --strict",
        "dialyzer",
        "sobelow --exit-on-warning",
        "deps.audit"
      ]
    ]
  end
end
