defmodule Singularity.MixProject do
  use Mix.Project

  @app :singularity

  def project do
    [
      app: @app,
      version: project_version(),
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      # mix_gleam integration (disabled)
      # archives: [mix_gleam: "~> 0.6.2"],
      erlc_paths: [
        "build/#{Mix.env()}/erlang/#{@app}/_gleam_artefacts",
        # For Gleam < v0.25.0 (kept for compatibility)
        "build/#{Mix.env()}/erlang/#{@app}/build"
      ],
      erlc_include_path: "build/#{Mix.env()}/erlang/#{@app}/include",
      # compilers: [:gleam | Mix.compilers()],  # Gleam disabled
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      prune_code_paths: false,
      # Memory limits for compilation
      erlc_options: [:debug_info, {:i, "include"}],
      erl_opts: [
        :debug_info,
        {:hmax, 268_435_456},  # 2GB max heap per process
        {:hmaxk, 524_288}      # 4GB system memory limit
      ],
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
        flags: [:error_handling, :underspecs, :unknown]
      ]
    ]
  end

  def application do
    [
      mod: {Singularity.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test_helpers"]
  defp elixirc_paths(_), do: ["lib"]

  defp project_version do
    "../VERSION"
    |> Path.expand(__DIR__)
    |> File.read!()
    |> String.trim()
  end

  defp deps do
    [
      # Minimal HTTP for health/metrics only
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

      # Rustler NIFs
      {:rustler, "~> 0.34.0", runtime: false},

      # All 9 Rust NIFs (compile: false = won't rebuild every time)
      {:architecture_engine, path: "native/architecture_engine", runtime: false, app: false, compile: false},
      {:code_engine, path: "native/code_engine", runtime: false, app: false, compile: false},
      {:framework_engine, path: "native/framework_engine", runtime: false, app: false, compile: false},
      {:knowledge_engine, path: "native/knowledge_engine", runtime: false, app: false, compile: false},
      {:package_engine, path: "native/package_engine", runtime: false, app: false, compile: false},
      {:parser_engine, path: "native/parser_engine", runtime: false, app: false, compile: false},
      {:prompt_engine, path: "native/prompt_engine", runtime: false, app: false, compile: false},
      {:quality_engine, path: "native/quality_engine", runtime: false, app: false, compile: false},
      {:semantic_engine, path: "native/semantic_engine", runtime: false, app: false, compile: false},

      # Data & Serialization
      {:jason, "~> 1.4"},
      {:nimble_options, "~> 1.1"},

      # T5 Training & LLM Integration
      {:bumblebee, "~> 0.5"},
      {:nx, "~> 0.6"},
      {:exla, "~> 0.6"},
      {:kino, "~> 0.12"},

      # Distributed Systems
      {:libcluster, "~> 3.3"},
      {:delta_crdt, "~> 0.6"},
      # NATS messaging
      {:gnat, "~> 1.8"},

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

      # Removed MCP - using real LLM providers with tools instead

      # Event Processing
      # Data pipelines
      {:broadway, "~> 1.0"},
      # Producer-consumer
      {:gen_stage, "~> 1.2"},
      # Parallel processing
      {:flow, "~> 1.2"},

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

      # Gleam integration
      # {:mix_gleam, "~> 0.6", runtime: false},  # Gleam disabled
      # {:gleam_stdlib, "~> 0.65", app: false, override: true}
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
      setup: ["deps.get", "gleam.deps.get", "deps.compile"],
      test: ["test"],
      "test.ci": ["test --color --cover"],
      coverage: ["coveralls.html"],
      quality: [
        "format",
        "credo --strict",
        "dialyzer",
        "sobelow --exit-on-warning",
        "deps.audit"
      ],
      "registry.sync": ["registry.sync"],
      "registry.report": ["registry.report"]
    ]
  end
end
