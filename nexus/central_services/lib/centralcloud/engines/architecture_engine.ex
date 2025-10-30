defmodule CentralCloud.Engines.ArchitectureEngine do
  @moduledoc """
  Architecture Engine - Delegates to Singularity via NATS.

  CentralCloud delegates architecture analysis requests to Singularity
  via NATS, which provides pure Elixir pattern detection via FrameworkDetector
  and TechnologyDetector.
  """

  require Logger
  alias QuantumFlow.Executor

  @doc """
  Detect frameworks in codebase.
  """
  def detect_frameworks(codebase_info, opts \\ []) do
    detection_type = Keyword.get(opts, :detection_type, "comprehensive")
    include_patterns = Keyword.get(opts, :include_patterns, true)
    include_technologies = Keyword.get(opts, :include_technologies, true)

    request = %{
      "codebase_info" => codebase_info,
      "detection_type" => detection_type,
      "include_patterns" => include_patterns,
      "include_technologies" => include_technologies
    }

    # Delegate to Singularity via NATS for architecture analysis
    case request_singularity("detect_frameworks", request) do
      {:ok, results} ->
        Logger.debug("Architecture engine detected frameworks",
          frameworks: length(Map.get(results, "frameworks", [])),
          patterns: length(Map.get(results, "patterns", []))
        )
        {:ok, results}

      {:error, reason} ->
        Logger.error("Architecture engine failed", reason: reason)
        {:error, reason}
    end
  end

  @doc """
  Detect technologies in codebase.
  """
  def detect_technologies(codebase_info, opts \\ []) do
    request = %{
      "codebase_info" => codebase_info,
      "detection_type" => Keyword.get(opts, :detection_type, "comprehensive")
    }

    # Delegate to Singularity via NATS for architecture analysis
    case request_singularity("detect_technologies", request) do
      {:ok, results} ->
        Logger.debug("Architecture engine detected technologies",
          technologies: length(Map.get(results, "technologies", []))
        )
        {:ok, results}

      {:error, reason} ->
        Logger.error("Architecture engine failed", reason: reason)
        {:error, reason}
    end
  end

  @doc """
  Get architectural suggestions for codebase.
  """
  def get_architectural_suggestions(codebase_info, opts \\ []) do
    request = %{
      "codebase_info" => codebase_info,
      "suggestion_type" => Keyword.get(opts, :suggestion_type, "comprehensive")
    }

    # Delegate to Singularity via NATS for architecture analysis
    case request_singularity("get_architectural_suggestions", request) do
      {:ok, results} ->
        Logger.debug("Architecture engine generated suggestions",
          suggestions: length(Map.get(results, "suggestions", []))
        )
        {:ok, results}

      {:error, reason} ->
        Logger.error("Architecture engine failed", reason: reason)
        {:error, reason}
    end
  end

  # Implement QuantumFlow delegation to Singularity (replaces NATS)
  defp request_singularity(operation, request) do
    payload = %{
      "operation" => operation,
      "request" => request,
      "source" => "centralcloud"
    }

    case Executor.execute(CentralCloud.Workflows.ArchitectureAnalysisWorkflow, payload,
           timeout: 60_000
         ) do
      {:ok, results} ->
        Logger.info("Architecture analysis workflow completed", operation: operation)
        {:ok, results}

      {:error, :timeout} ->
        Logger.warning("Architecture analysis workflow timed out", operation: operation)

        {:ok,
         %{
           "status" => "timeout",
           "operation" => operation,
           "results" => %{
             "technologies" => ["unknown"],
             "suggestions" => ["Analysis timed out - using fallback results"]
           }
         }}

      {:error, reason} ->
        Logger.error("Architecture analysis workflow failed", operation: operation, reason: reason)
        {:error, reason}
    end
  end
end
