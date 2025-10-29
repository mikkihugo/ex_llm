defmodule CentralCloud.Engines.LintingEngine do
  @moduledoc """
  Linting Engine – delegates code quality analysis to Singularity via PGFlow.

  CentralCloud keeps Rust NIF compilation disabled, so all linting and quality
  evaluation runs inside Singularity. This module provides a thin façade that
  packages requests, sends them through PGFlow, and returns the structured
  responses.
  """

  require Logger
  alias Pgflow

  @default_quality_checks ["maintainability", "performance", "security", "architecture"]
  @default_languages ["elixir", "rust", "javascript"]

  @doc """
  Analyze code quality for a repository or project.

  Options:
    * `:quality_checks` - list of checks to run (defaults to #{@default_quality_checks |> Enum.join(", ")})
    * `:include_metrics` - boolean flag controlling metric enrichment (default: true)
  """
  def analyze_quality(codebase_info, opts \\ []) do
    request = %{
      "codebase_info" => codebase_info,
      "quality_checks" => Keyword.get(opts, :quality_checks, @default_quality_checks),
      "include_metrics" => Keyword.get(opts, :include_metrics, true)
    }

    with {:ok, results} <- linting_engine_call("analyze_quality", request) do
      Logger.debug("Linting engine quality analysis completed",
        overall_score: Map.get(results, "overall_score", 0.0),
        checks_performed: length(Map.get(results, "quality_checks", []))
      )

      {:ok, results}
    end
  end

  @doc """
  Run linting passes across the supplied codebase metadata.

  Options:
    * `:languages` - target languages (default #{@default_languages |> Enum.join(", ")})
    * `:strict_mode` - enable stricter lint rules (default false)
  """
  def run_linting(codebase_info, opts \\ []) do
    request = %{
      "codebase_info" => codebase_info,
      "languages" => Keyword.get(opts, :languages, @default_languages),
      "strict_mode" => Keyword.get(opts, :strict_mode, false)
    }

    with {:ok, results} <- linting_engine_call("run_linting", request) do
      Logger.debug("Linting engine linting completed",
        issues_found: length(Map.get(results, "issues", []))
      )

      {:ok, results}
    end
  end

  # ---------------------------------------------------------------------------
  # PGFLOW DELEGATION
  # ---------------------------------------------------------------------------

  defp linting_engine_call(operation, request) do
    case Pgflow.send_with_notify("engine.linting.#{operation}", request, CentralCloud.Repo,
           timeout: 30_000
         ) do
      {:ok, response} ->
        {:ok, response}

      {:error, :timeout} ->
        Logger.error("Linting engine call timed out", operation: operation)
        {:error, :timeout}

      {:error, reason} ->
        Logger.error("Linting engine call failed", operation: operation, reason: inspect(reason))
        {:error, reason}
    end
  end
end
