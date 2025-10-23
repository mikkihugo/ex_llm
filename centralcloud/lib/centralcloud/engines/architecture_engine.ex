defmodule Centralcloud.Engines.ArchitectureEngine do
  @moduledoc """
  Architecture Engine - Delegates to Singularity via NATS.

  This module provides a simple interface to Singularity's Rust architecture
  analysis engine via NATS messaging. CentralCloud does not compile its own
  copy of the Rust NIF; instead it uses the Singularity instance's compiled
  engines through the SharedEngineService.
  """

  alias Centralcloud.Engines.SharedEngineService
  require Logger

  @doc """
  Detect frameworks in codebase using Singularity's Rust Architecture Engine.

  Delegates to Singularity via NATS for the actual computation.
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

    SharedEngineService.call_architecture_engine("detect_frameworks", request, timeout: 30_000)
  end

  @doc """
  Detect technologies in codebase.

  Delegates to Singularity via NATS for the actual computation.
  """
  def detect_technologies(codebase_info, opts \\ []) do
    request = %{
      "codebase_info" => codebase_info,
      "detection_type" => Keyword.get(opts, :detection_type, "comprehensive")
    }

    SharedEngineService.call_architecture_engine("detect_technologies", request, timeout: 30_000)
  end

  @doc """
  Get architectural suggestions for codebase.

  Delegates to Singularity via NATS for the actual computation.
  """
  def get_architectural_suggestions(codebase_info, opts \\ []) do
    request = %{
      "codebase_info" => codebase_info,
      "suggestion_type" => Keyword.get(opts, :suggestion_type, "comprehensive")
    }

    SharedEngineService.call_architecture_engine("get_architectural_suggestions", request, timeout: 30_000)
  end
end
