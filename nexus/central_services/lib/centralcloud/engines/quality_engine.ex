defmodule CentralCloud.Engines.LintingEngine do
  @moduledoc """
  Linting Engine - Delegates to Singularity via NATS.

  CentralCloud doesn't compile Rust NIFs directly (compile: false in mix.exs).
  Instead, this module delegates linting & quality gate requests to Singularity
  via NATS, which has the compiled linting_engine NIF.

  This module provides linting integration, quality gate enforcement, and external
  linter coordination (ESLint, Clippy, Credo, etc.).
  """

  # Note: Rustler bindings disabled - NIFs compiled only in Singularity
  # use Rustler,
  #   otp_app: :centralcloud,
  #   crate: :linting_engine,
  #   path: "../../../../rust/linting_engine"

  require Logger

  @doc """
  Analyze code quality using Rust Quality Engine.
  """
  def analyze_quality(codebase_info, opts \\ []) do
    quality_checks = Keyword.get(opts, :quality_checks, ["maintainability", "performance", "security", "architecture"])
    include_metrics = Keyword.get(opts, :include_metrics, true)

    request = %{
      "codebase_info" => codebase_info,
      "quality_checks" => quality_checks,
      "include_metrics" => include_metrics
    }

    case linting_engine_call("analyze_quality", request) do
      {:ok, results} ->
        Logger.debug("Linting engine quality analysis completed",
          overall_score: Map.get(results, "overall_score", 0.0),
          checks_performed: length(Map.get(results, "quality_checks", []))
        )
        {:ok, results}

      {:error, reason} ->
        Logger.error("Linting engine failed", reason: reason)
        {:error, reason}
    end
  end

  @doc """
  Run linting on codebase.
  """
  def run_linting(codebase_info, opts \\ []) do
    languages = Keyword.get(opts, :languages, ["elixir", "rust", "javascript"])
    strict_mode = Keyword.get(opts, :strict_mode, false)

    request = %{
      "codebase_info" => codebase_info,
      "languages" => languages,
      "strict_mode" => strict_mode
    }

    case linting_engine_call("run_linting", request) do
      {:ok, results} ->
        Logger.debug("Linting engine linting completed",
          issues_found: length(Map.get(results, "issues", []))
        )
        {:ok, results}

      {:error, reason} ->
        Logger.error("Linting engine failed", reason: reason)
        {:error, reason}
    end
  end

  # NIF function (loaded from shared Rust crate)
  defp linting_engine_call(_operation, _request), do: :erlang.nif_error(:nif_not_loaded)
end
