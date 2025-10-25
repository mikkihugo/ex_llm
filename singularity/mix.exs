defmodule Singularity.MixProject do
  use Mix.Project

  @app :singularity

  def project do
    [
      app: @app,
      version: project_version(),
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      prune_code_paths: false,
      # Memory limits for compilation
      erlc_options: [:debug_info, {:i, "include"}],
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

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp project_version do
    "../VERSION"
    |> Path.expand(__DIR__)
    |> File.read!()
    |> String.trim()
  end

  defp deps do
    [
      # Web interface (Phoenix LiveDashboard)
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, "~> 0.20"},
      {:phoenix_html, "~> 4.0"},
      {:bandit, "~> 1.5"},
      {:plug, "~> 1.15"},
      {:finch, "~> 0.17"},
      {:req, "~> 0.5"},

      # UI Component Library (inspired by shadcn/ui)
      {:salad_ui, "~> 0.14"},

      # Database
      {:ecto, "~> 3.11"},
      {:ecto_sql, "~> 3.11"},
      {:postgrex, ">= 0.0.0"},
      # Vector embeddings for pattern mining
      {:pgvector, "~> 0.2"},

      # Rustler NIFs
      {:rustler, "~> 0.37", runtime: false},

      # Rust NIFs with Rustler integration (compile: false)
      # Rustler NIF compilation happens via Elixir modules that call `use Rustler`
      # Each module has: use Rustler, otp_app: :singularity, crate: :engine_name, path: ../..
      # NIFs are compiled on-demand when modules are loaded, not via Mix dependency compilation
      # Note: architecture_engine removed - uses pure Elixir detectors instead
      {:code_quality_engine,
       path: "../rust/code_quality_engine", runtime: false, compile: false, app: false},
      # Embedding now uses pure Elixir (NxService) instead of Rust NIF
      # knowledge_engine consolidated into architecture_engine
      {:parser_engine,
       path: "../rust/parser_engine", runtime: false, compile: false, app: false, optional: true},
      {:prompt_engine,
       path: "../rust/prompt_engine", runtime: false, compile: false, app: false, optional: true},
      {:linting_engine,
       path: "../rust/linting_engine", runtime: false, compile: false, app: false},
      # Other engines are symlinks to rust/ or rust-central/ directories (already included in workspace)

      # Data & Serialization
      {:jason, "~> 1.4"},
      {:nimble_options, "~> 1.1"},
      # Templating engines
      {:solid, "~> 0.14"},
      # Lua on BEAM for dynamic prompt scripts (ergonomic luerl wrapper)
      # When luerl 2.0 releases, this will be merged into luerl directly
      {:lua, "~> 0.3.0"},

      # ML/AI Framework - Pure Elixir Nx + Axon + EXLA
      # Bumblebee for pre-trained models (optional, helps with HF integration)
      {:bumblebee, "~> 0.5", optional: true},
      # Core tensor operations (required)
      {:nx, "~> 0.6"},
      # Neural network framework for fine-tuning (required for Axon)
      {:axon, "~> 0.6", optional: true},
      # GPU acceleration (CUDA/Metal) - RTX 4080 support (optional, required for GPU)
      {:exla, "~> 0.6", optional: true, app: false},
      # {:kino, "~> 0.12"},

      # Distributed Systems
      {:libcluster, "~> 3.3"},
      {:delta_crdt, "~> 0.6"},
      # NATS messaging
      {:gnat, "~> 1.8"},

      # Structured LLM outputs with validation (Instructor)
      {:instructor, "~> 0.1"},

      # File watching for real-time code ingestion
      {:file_system, "~> 1.0"},

      # Monitoring & Telemetry
      {:telemetry, "~> 1.2"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.1"},
      {:phoenix_live_dashboard, "~> 0.8"},

      # Background Job Queue for ML training, maintenance tasks, and cron scheduling
      {:oban, "~> 2.18"},

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
      setup: ["deps.get", "deps.compile"],
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
      "registry.report": ["registry.report"],
      # Compile with only Singularity warnings (filter out dependency warnings)
      "compile.only": ["compile.filtered"]
    ]
  end
end
