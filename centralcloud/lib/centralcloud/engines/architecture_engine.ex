defmodule Centralcloud.Engines.ArchitectureEngine do
  @moduledoc """
  Architecture Engine NIF - Direct bindings to Rust architecture analysis.
  
  This module loads the same Rust NIF as Singularity, allowing Centralcloud
  to use the same architecture analysis capabilities directly.
  """

  use Rustler, 
    otp_app: :centralcloud,
    crate: :architecture_engine,
    path: "../rust/architecture_engine",
    skip_compilation?: false

  require Logger

  @doc """
  Detect frameworks in codebase using Rust Architecture Engine.
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

    case architecture_engine_call("detect_frameworks", request) do
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

    case architecture_engine_call("detect_technologies", request) do
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

    case architecture_engine_call("get_architectural_suggestions", request) do
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

  # NIF function (loaded from Rust)
  defp architecture_engine_call(_operation, _request), do: :erlang.nif_error(:nif_not_loaded)
end
