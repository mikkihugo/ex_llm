defmodule Centralcloud.Engines.QualityEngine do
  @moduledoc """
  Quality Engine NIF - Direct bindings to Rust quality analysis.

  This module loads the shared Rust NIF from the project root rust/ directory,
  allowing CentralCloud to use the same compiled quality engine as Singularity.
  """

  use Rustler,
    otp_app: :centralcloud,
    crate: :quality_engine,
    path: "../../../rust/quality_engine"

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

    case quality_engine_call("analyze_quality", request) do
      {:ok, results} ->
        Logger.debug("Quality engine analysis completed",
          overall_score: Map.get(results, "overall_score", 0.0),
          checks_performed: length(Map.get(results, "quality_checks", []))
        )
        {:ok, results}

      {:error, reason} ->
        Logger.error("Quality engine failed", reason: reason)
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

    case quality_engine_call("run_linting", request) do
      {:ok, results} ->
        Logger.debug("Quality engine linting completed",
          issues_found: length(Map.get(results, "issues", []))
        )
        {:ok, results}

      {:error, reason} ->
        Logger.error("Quality engine failed", reason: reason)
        {:error, reason}
    end
  end

  # NIF function (loaded from shared Rust crate)
  defp quality_engine_call(_operation, _request), do: :erlang.nif_error(:nif_not_loaded)
end
