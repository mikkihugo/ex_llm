defmodule CentralCloud.Engines.CodeEngine do
  @moduledoc """
  High-level façade for Singularity's code analysis engine accessed via PGFlow.

  CentralCloud forwards code understanding requests (business domain detection,
  pattern analysis, etc.) to Singularity, which hosts the compiled Rust NIFs.
  """

  require Logger
  alias Pgflow

  @default_analysis_types ["business_domains", "patterns", "architecture"]

  @doc """
  Analyze a codebase for domains, patterns, and architectural signals.
  """
  def analyze_codebase(codebase_info, opts \\ []) do
    request = %{
      "codebase_info" => codebase_info,
      "analysis_types" => Keyword.get(opts, :analysis_types, @default_analysis_types),
      "include_embeddings" => Keyword.get(opts, :include_embeddings, true)
    }

    with {:ok, results} <- code_quality_engine_call("analyze_codebase", request) do
      Logger.debug("Code engine analysis completed",
        business_domains: length(Map.get(results, "business_domains", [])),
        patterns: length(Map.get(results, "patterns", []))
      )

      {:ok, results}
    end
  end

  @doc """
  Detect business domains with a configurable confidence threshold.
  """
  def detect_business_domains(codebase_info, opts \\ []) do
    request = %{
      "codebase_info" => codebase_info,
      "confidence_threshold" => Keyword.get(opts, :confidence_threshold, 0.7)
    }

    with {:ok, results} <- code_quality_engine_call("detect_business_domains", request) do
      Logger.debug("Code engine detected business domains",
        domains: length(Map.get(results, "business_domains", []))
      )

      {:ok, results}
    end
  end

  # ---------------------------------------------------------------------------
  # PGFLOW DELEGATION
  # ---------------------------------------------------------------------------

  defp code_quality_engine_call(operation, request) do
    case Pgflow.send_with_notify("engine.code.#{operation}", request, CentralCloud.Repo,
           timeout: 30_000
         ) do
      {:ok, response} ->
        {:ok, response}

      {:error, :timeout} ->
        Logger.error("Code quality engine call timed out", operation: operation)
        {:error, :timeout}

      {:error, reason} ->
        Logger.error("Code quality engine call failed", operation: operation, reason: inspect(reason))
        {:error, reason}
    end
  end
end
