defmodule SeedAgent.MixProject do
  use Mix.Project

  @app :seed_agent

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
      archives: [mix_gleam: "~> 0.6"],
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
      mod: {SeedAgent.Application, []},
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
      {:bandit, "~> 1.5"},
      {:plug, "~> 1.15"},
      {:jason, "~> 1.4"},
      {:libcluster, "~> 3.3"},
      {:telemetry, "~> 1.2"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.1"},
      {:req, "~> 0.5"},
      {:finch, "~> 0.17"},
      {:nimble_options, "~> 1.1"},
      {:delta_crdt, "~> 0.6"},
      {:gleam_stdlib, "~> 0.65", app: false, manager: :rebar3, override: true},
      {:gleeunit, "~> 1.0", app: false, manager: :rebar3, only: [:dev, :test]},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp releases do
    [
      seed_agent: [
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
      quality: ["format", "credo --strict", "dialyzer"]
    ]
  end
end
